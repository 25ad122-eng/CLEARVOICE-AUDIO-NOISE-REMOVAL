library(shiny)
library(tuneR)
library(signal)
library(ggplot2)

options(shiny.maxRequestSize = 100 * 1024^2)

read_audio_mono <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext != "wav") stop("Please upload a WAV file. Convert MP3/M4A to WAV before uploading.")
  w <- tuneR::readWave(path)
  if (w@stereo) {
    x <- (as.numeric(w@left) + as.numeric(w@right)) / 2
  } else x <- as.numeric(w@left)
  list(x = x, samp.rate = w@samp.rate, bit = w@bit, original = w)
}

# Lightweight spectral-gating denoiser. Estimates a noise profile from the
# beginning of the recording and attenuates bins close to that noise floor.
spectral_denoise <- function(x, sample_rate, noise_seconds = 0.35, strength = 1.5, floor = 0.08) {
  x <- as.numeric(x)
  if (length(x) < 1024) return(x)
  n <- 1024L
  hop <- 512L
  if (length(x) < n) n <- 2^floor(log2(length(x)))
  hop <- max(1L, floor(n / 2))
  win <- 0.5 - 0.5 * cos(2*pi*(0:(n-1))/(n-1))
  starts <- seq(1L, max(1L, length(x)-n+1L), by=hop)
  if (tail(starts,1) + n - 1L < length(x)) starts <- c(starts, length(x)-n+1L)
  frames <- lapply(starts, function(s) {
    z <- x[s:(s+n-1L)]
    as.vector(fft(z * win))
  })
  noise_n <- max(1L, min(length(frames), ceiling(noise_seconds * sample_rate / hop)))
  # Noise profile from first few frames; robust to speech beginning immediately.
  noise_profile <- Reduce(`+`, lapply(frames[seq_len(noise_n)], function(f) Mod(f))) / noise_n
  cleaned <- vector("list", length(frames))
  for (i in seq_along(frames)) {
    f <- frames[[i]]
    mag <- Mod(f)
    phase <- Arg(f)
    clean_mag <- pmax(mag - strength * noise_profile, floor * mag)
    cleaned[[i]] <- clean_mag * exp(1i * phase)
  }
  out <- numeric(length(x)); weight <- numeric(length(x))
  for (i in seq_along(starts)) {
    s <- starts[i]
    frame <- Re(fft(cleaned[[i]], inverse=TRUE) / n) * win
    idx <- s:(s+n-1L)
    out[idx] <- out[idx] + frame
    weight[idx] <- weight[idx] + win^2
  }
  valid <- weight > 1e-8
  out[valid] <- out[valid] / weight[valid]
  out[!valid] <- x[!valid]
  out
}

process_audio <- function(path, method, strength, cutoff, gate) {
  a <- read_audio_mono(path)
  x <- a$x
  sr <- a$samp.rate
  if (method == "Spectral noise reduction") {
    y <- spectral_denoise(x, sample_rate=sr, strength=strength)
  } else {
    y <- x
  }
  if (cutoff > 0 && cutoff < sr/2) {
    bf <- signal::butter(4, cutoff/(sr/2), type="high")
    y <- as.numeric(signal::filtfilt(bf, y))
  }
  if (gate > 0) {
    threshold <- max(abs(y), na.rm=TRUE) * gate
    y[abs(y) < threshold] <- y[abs(y) < threshold] * 0.12
  }
  peak <- max(abs(y), na.rm=TRUE)
  if (peak > 0) y <- y / peak * 0.95
  list(original=x, cleaned=y, sr=sr, bit=a$bit)
}

ui <- fluidPage(
  titlePanel("ClearVoice | Audio Noise Reduction Studio"),
  sidebarLayout(
    sidebarPanel(
      h4("1. Upload audio"),
      fileInput("audio", "Choose a WAV file", accept=c(".wav", "audio/wav")),
      helpText("For best results, use a recording with a short section of background noise at the beginning."),
      h4("2. Processing settings"),
      selectInput("method", "Noise reduction method", c("Spectral noise reduction", "Filters only")),
      sliderInput("strength", "Noise reduction strength", min=0.5, max=3.5, value=1.5, step=0.1),
      sliderInput("cutoff", "High-pass cutoff (Hz; 0 disables)", min=0, max=1000, value=80, step=10),
      sliderInput("gate", "Low-level noise gate", min=0, max=0.15, value=0.015, step=0.005),
      actionButton("run", "Clean audio", class="btn-primary"),
      br(), br(), downloadButton("download", "Download cleaned WAV")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Overview", br(), h4("How it works"),
                 p("ClearVoice uses local signal processing. Spectral noise reduction estimates a noise profile from the opening frames, attenuates similar frequency components, and reconstructs the audio. A high-pass filter and optional low-level gate can further reduce rumble and quiet background noise."),
                 p("Important: this is a classical signal-processing method, not a neural-network speech model. Results depend on the recording and settings."),
                 verbatimTextOutput("status")),
        tabPanel("Waveforms", br(), plotOutput("waveplot", height="330px"), plotOutput("specplot", height="330px")),
        tabPanel("Playback", br(), h4("Original recording"), uiOutput("original_player"), h4("Cleaned recording"), uiOutput("clean_player"),
                 p("Audio playback is generated locally in this Shiny session."))
      )
    )
  )
)

server <- function(input, output, session) {
  result <- eventReactive(input$run, {
    req(input$audio)
    tryCatch(process_audio(input$audio$datapath, input$method, input$strength, input$cutoff, input$gate),
             error=function(e) { showNotification(conditionMessage(e), type="error", duration=NULL); NULL })
  })
  write_temp_wav <- function(x, sr) {
    x <- pmax(-1, pmin(1, x / max(1, max(abs(x))) * 0.98))
    path <- tempfile(fileext=".wav")
    tuneR::writeWave(tuneR::Wave(left=as.integer(x*32767), samp.rate=sr, bit=16), path)
    path
  }
  output$status <- renderPrint({
    req(input$audio)
    cat("File:", input$audio$name, "\n")
    if (!is.null(result())) cat("Processing complete. Use Playback to listen and Waveforms to compare the signal.\n") else cat("Click Clean audio to process the uploaded WAV file.\n")
  })
  output$waveplot <- renderPlot({
    req(input$audio)
    a <- read_audio_mono(input$audio$datapath)
    d <- data.frame(time=seq_along(a$x)/a$samp.rate, amplitude=a$x/max(1e-9,max(abs(a$x))), signal="Original")
    if (!is.null(result())) {
      r <- result(); d2 <- data.frame(time=seq_along(r$cleaned)/r$sr, amplitude=r$cleaned/max(1,max(abs(r$cleaned))), signal="Cleaned")
      d <- rbind(d, d2)
    }
    ggplot(d, aes(time, amplitude, color=signal)) + geom_line(linewidth=0.25) + facet_wrap(~signal, ncol=1) +
      labs(title="Waveform comparison", x="Time (seconds)", y="Normalized amplitude") + theme_minimal() + theme(legend.position="none")
  })
  output$specplot <- renderPlot({
    req(input$audio)
    a <- read_audio_mono(input$audio$datapath)
    x <- a$x
    if (!is.null(result())) x <- result()$cleaned
    n <- min(length(x), a$samp.rate*8)
    spec <- abs(fft(x[seq_len(n)]))
    half <- floor(length(spec)/2)
    df <- data.frame(freq=(0:(half-1))*a$samp.rate/n, magnitude=20*log10(spec[1:half]+1))
    ggplot(df, aes(freq, magnitude)) + geom_line() + coord_cartesian(xlim=c(0, min(8000, a$samp.rate/2))) +
      labs(title=if (is.null(result())) "Original frequency spectrum" else "Cleaned frequency spectrum", x="Frequency (Hz)", y="Magnitude (dB, relative)") + theme_minimal()
  })
  output$original_player <- renderUI({
    req(input$audio)
    tags$audio(controls=NA, src=paste0("data:audio/wav;base64,", jsonlite::base64_enc(readBin(input$audio$datapath, "raw", n=file.info(input$audio$datapath)$size))), type="audio/wav", style="width:100%")
  })
  output$clean_player <- renderUI({
    req(result())
    r <- result(); path <- write_temp_wav(r$cleaned, r$sr)
    tags$audio(controls=NA, src=paste0("data:audio/wav;base64,", jsonlite::base64_enc(readBin(path, "raw", n=file.info(path)$size))), type="audio/wav", style="width:100%")
  })
  output$download <- downloadHandler(
    filename=function() paste0("clearvoice_cleaned_", Sys.Date(), ".wav"),
    content=function(file) { req(result()); r <- result(); tuneR::writeWave(tuneR::Wave(left=as.integer(pmax(-1,pmin(1,r$cleaned))*32767), samp.rate=r$sr, bit=16), file) }
  )
}
shinyApp(ui, server)
