# cplot R shim - defines cp() and writes renders into the staging dir.
local({
  stage <- Sys.getenv("CPLOT_STAGE")
  if (!nzchar(stage)) stop("cplot: CPLOT_STAGE not set")

  emit <- function(name, png, svg, w, h, dpi) {
    line <- sprintf(
      '{"name":"%s","png":"%s","svg":%s,"w":%s,"h":%s,"dpi":%s}',
      name, png, if (is.null(svg)) "null" else sprintf('"%s"', svg), w, h, dpi)
    cat(line, "\n", sep = "", file = file.path(stage, "emitted.jsonl"), append = TRUE)
  }

  render <- function(plot, path, w, h, dpi, dev = c("png", "svg")) {
    dev <- match.arg(dev)
    is_gg <- inherits(plot, "ggplot") || inherits(plot, "patchwork")
    if (is_gg && requireNamespace("ggplot2", quietly = TRUE)) {
      ggplot2::ggsave(path, plot, width = w, height = h, dpi = dpi,
                      device = dev, limitsize = FALSE)
      return(invisible())
    }
    if (dev == "png") {
      if (requireNamespace("ragg", quietly = TRUE)) {
        ragg::agg_png(path, width = w, height = h, units = "in", res = dpi)
      } else {
        grDevices::png(path, width = w, height = h, units = "in", res = dpi, type = "cairo")
      }
    } else {
      if (requireNamespace("svglite", quietly = TRUE)) svglite::svglite(path, width = w, height = h)
      else grDevices::svg(path, width = w, height = h)
    }
    on.exit(grDevices::dev.off(), add = TRUE)
    if (is.function(plot)) plot()
    else if (inherits(plot, "recordedplot")) grDevices::replayPlot(plot)
    else print(plot)
    invisible()
  }

  cp_fn <- function(plot, suffix = NULL, svg = NULL,
                    width = NULL, height = NULL, dpi = NULL) {
    base <- Sys.getenv("CPLOT_NAME")
    name <- if (is.null(suffix)) base else paste0(base, "-", suffix)
    w <- as.numeric(if (is.null(width))  Sys.getenv("CPLOT_W")   else width)
    h <- as.numeric(if (is.null(height)) Sys.getenv("CPLOT_H")   else height)
    d <- as.numeric(if (is.null(dpi))    Sys.getenv("CPLOT_DPI") else dpi)
    want_svg <- if (is.null(svg)) nzchar(Sys.getenv("CPLOT_SVG")) else isTRUE(svg)
    png <- file.path(stage, paste0(name, ".png"))
    render(plot, png, w, h, d, "png")
    sp <- NULL
    if (want_svg) {
      sp <- file.path(stage, paste0(name, ".svg"))
      try(render(plot, sp, w, h, d, "svg"), silent = TRUE)
      if (!file.exists(sp)) sp <- NULL
    }
    emit(name, png, sp, w, h, d)
    invisible(png)
  }

  assign("cp", cp_fn, envir = globalenv())
})
