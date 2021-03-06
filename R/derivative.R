# ' @rdname derivative
# ' @export
hess.phenofit <- function(fit, tout){
    FUN <- get(fit$fun, mode = 'function')
    grad(function(t) grad(FUN, t, par= fit$par), tout)
}


# ' Get gradient and hessian by \code{grad} in \code{numDeriv} package.
# '
# ' @param fit A curve fitting object returned by \code{curvefit}.
# ' @param tout A vector of time steps at which the function can be predicted.
# '
# ' @examples
# ' FUN <- doubleLog.Beck
# ' 
# ' @rdname derivative
# ' @export
grad.phenofit <- function(fit, tout){
    FUN <- get(fit$fun, mode = 'function')
    grad(FUN, tout, par = fit$par)
}

# FUN <- doubleLog.Beck
# par <- c(
#     mn = 0.1, mx = 0.7,
#     sos = 100, rsp = 0.15,
#     eos = 250, rau = 0.15)
# t    <- seq(1, 365, 8)
# tout <- seq(1, 365, 1)
# y <- FUN(par, t) + rnorm(length(t), sd = 0.5)


#' @title D
#' @name D
#' 
#' @description Get derivative of \code{phenofit} object.
#' \code{D1} first order derivative, \code{D2} second order derivative.
#'
#' @details If \code{fit$fun} has no gradient function or \code{smoothed.spline = TRUE}, 
#' time-series smoothed by spline first, and get derivatives at last. 
#' If \code{fit$fun} exists and \code{analytical = TRUE}, \code{smoothed.spline} 
#' will be ignored.
#'  
#' @param fit A curve fitting object returned by \code{curvefit}.
#' @param analytical If true, \code{numDeriv} package \code{grad} and \code{hess}
#' will be used; if false, \code{D1} and \code{D2} will be used.
#' @param smoothed.spline Whether apply \code{smooth.spline} first?
#' @param ... Other parameters will be ignored.
#' 
#' @rdname D
NULL

#' @rdname D
#' @export
D1 <- function(fit, analytical = TRUE, smoothed.spline = FALSE, ...) UseMethod('D1', fit)

#' @rdname D
#' @export
D2 <- function(fit, analytical = TRUE, smoothed.spline = FALSE, ...) UseMethod('D2', fit)

#' @rdname D
#' @export
D1.phenofit <- function(fit, analytical = TRUE, smoothed.spline = FALSE, ...){
    pred <- last(fit$fits)
    t    <- fit$tout
    par  <- fit$par

    FUN <- get(fit$fun, mode = 'function')
    D1  <- attr(FUN, 'gradient')# first order derivative, D1 was 6 times faster
                                # than grad, and 20 times faster then diff
    # the derivate of curve fitting time-series

    if (analytical && !is.null(D1)) smoothed.spline <- FALSE

    if (is.null(D1) || smoothed.spline) {
        # 1. Numerical solution
        spline.eq <- smooth.spline(pred, df = length(pred))
        der1      <- predict(spline.eq, d = 1)$y
        # der1 <- diff(pred)/diff(t)
    } else if (analytical){
        # real analytical
        der1 <- D1(par, t)[, 1] # the default option
    } else {
        # numerical approximation
        der1 <- grad.phenofit(fit, t)     
    }

    der1[is.infinite(der1)] <- NA
    #rule = 2, means y range out of xlim also could get a approximate value
    if (any(is.na(der1))) der1 %<>% na.approx(rule = 2)
    return(der1)
}

#' @rdname D
#' @export
D2.phenofit <- function(fit, analytical = TRUE, smoothed.spline = FALSE, ...){
    pred <- last(fit$fits)
    t    <- fit$tout
    par  <- fit$par

    FUN  <- get(fit$fun, mode = 'function')
    D1   <- attr(FUN, 'gradient') # first order derivative, D1 was 6 times faster
                                  # than grad, and 20 times faster then diff
    D2   <- attr(FUN, 'hessian')  # second order derivative

    if (is.null(D1) || smoothed.spline) {
        # 1. Numerical solution
        spline.eq <- smooth.spline(pred, df = length(pred))
        der1      <- predict(spline.eq, d = 1)$y
        der2      <- predict(spline.eq, d = 2)$y
    } else if (analytical){
        # real analytical
        der1 <- D1(par, t)[, 1]
        der2 <- D2(par, t)[, 1, 1]
    } else {
        # numerical approximation
        der1 <- grad.phenofit(fit, t)
        der2 <- hess.phenofit(fit, t)
    }
    
    ## in case for NA values
    der1[is.infinite(der1)] <- NA
    der2[is.infinite(der2)] <- NA
    if (any(is.na(der1))) der1 %<>% na.approx(rule = 2)
    if (any(is.na(der2))) der2 %<>% na.approx(rule = 2)

    return(list(der1 = der1, der2 = der2))
}

#' curvature
#' @inheritParams D1
#' @export
curvature <- function(fit, analytical = TRUE, smoothed.spline = FALSE, ...) UseMethod('curvature', fit)

#' @export
curvature.phenofit <- function(fit, analytical = TRUE, smoothed.spline = FALSE, ...){
    derivs <- D2.phenofit(fit, analytical, smoothed.spline)
    k      <- derivs$der2 / (1 + derivs$der1 ^ 2) ^ (3 / 2)
    return(list(k = k, der1 = derivs$der1, der2 = derivs$der2))
}
