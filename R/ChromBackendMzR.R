#' @include hidden_aliases.R
NULL

setClass("ChromBackendMzR", contains = "ChromBackendDataFrame",
         prototype = prototype(version = "0.1", readonly = TRUE))

setValidity("ChromBackendMzR", function(object) {
    msg <- .valid_chrom_data_required_columns(object@chromData,
                                              c("dataStorage", "chromIndex"))
    msg <- c(msg, .valid_chrom_backend_files_exist(
                      unique(object@chromData$dataStorage)))
    if (length(msg)) msg
    else TRUE
})

#' @rdname hidden_aliases
#'
#' @importFrom methods callNextMethod
#'
#' @importMethodsFrom BiocParallel bplapply
#'
#' @importFrom BiocParallel bpparam
setMethod("backendInitialize", "ChromBackendMzR",
          function(object, files, ..., BPPARAM = bpparam()) {
              if (missing(files) || !length(files))
                  stop("Parameter 'files' is mandatory for 'ChromBackendMzR'")
              if (!is.character(files))
                  stop("Parameter 'files' is expected to be a character vector",
                       " with the files names from where data should be",
                       " imported")
              files <- normalizePath(files)
              msg <- .valid_chrom_backend_files_exist(files)
              if (length(msg))
                  stop(msg)
              chromData <- do.call(
                  rbind, bplapply(files,
                                  FUN = function(fl) {
                                      cbind(Chromatograms:::.mzR_chrom_header(fl),
                                            dataStorage = fl)
                                  }, BPPARAM = BPPARAM))
              chromData$dataOrigin <- chromData$dataStorage
              object@chromData <- asRleDataFrame(
                  chromData, columns = c("dataStorage", "dataOrigin"))
              validObject(object)
              object
          })

#' @rdname hidden_aliases
setMethod("show", "ChromBackendMzR", function(object) {
    callNextMethod()
    fls <- unique(dataStorage(object))
    if (length(fls)) {
        to <- min(3, length(fls))
        cat("\nfile(s):\n", paste(basename(fls[1:to]), collapse = "\n"),
            "\n", sep = "")
        if (length(fls) > 3)
            cat(" ...", length(fls) - 3, "more files\n")
    }
})

#' @rdname hidden_aliases
#'
setMethod("as.list", "ChromBackendMzR", function(x) {
    .rtime_intensity_pairs_mzR(x)
})

#' @rdname hidden_aliases
#'
#' @importFrom methods as
setMethod("chromData", "ChromBackendMzR",
          function(object, columns = chromVariables(object)) {
              .chrom_data_mzR(object, columns)
          })

#' @rdname hidden_aliases
setReplaceMethod("chromData", "ChromBackendMzR", function(object, value) {
    if ((inherits(value, "DataFrame") | is.data.frame(value))
        && any(colnames(value) %in% c("rtime", "intensity"))) {
        warning("Ignoring columns \"rtime\" and \"intensity\" as the ",
                "'ChromBackendMzR' backend currently does not support ",
                "replacing them.")
        value <- value[, !(colnames(value) %in% c("rtime", "intensity")),
                       drop = FALSE]
    }
    object@chromData <- asRleDataFrame(value, columns = c("dataStorage",
                                                          "dataOrigin"))
    validObject(object)
    object
})

#' @rdname hidden_aliases
setMethod("intensity", "ChromBackendMzR", function(object) {
    NumericList(lapply(.rtime_intensity_pairs_mzR(object), "[", , 2),
                compress = FALSE)
})

#' @rdname hidden_aliases
setReplaceMethod("intensity", "ChromBackendMzR", function(object, value) {
    stop(class(object), " does not support replacing intensity values")
})

#' @rdname hidden_aliases
setMethod("rtime", "ChromBackendMzR", function(object) {
    NumericList(lapply(.rtime_intensity_pairs_mzR(object), "[", , 1),
                compress = FALSE)
})

#' @rdname hidden_aliases
setReplaceMethod("rtime", "ChromBackendMzR", function(object, value) {
    stop(class(object), " does not support replacing m/z values")
})

#' @rdname hidden_aliases
setReplaceMethod("$", "ChromBackendMzR", function(x, name, value) {
    if (name == "rtime" || name == "intensity")
        stop("'ChromBackendMzR' does not support replacing retention time ",
             "or intensity values")
    value_len <- length(value)
    if (value_len == 1)
        x@chromData[[name]] <- Rle(value, length(x))
    else if (value_len == length(x))
        x@chromData[[name]] <- asRle(value)
    else
        stop("Length of 'value' has to be either 1 or ", length(x))
    validObject(x)
    x
})
