#' @title IMIX
#' @description Fitting a multivariate mixture model framework, model selection for the best model, and adaptive procedure for FDR control. Input of summary statistics z scores of two or three data types.
#'
#' @param data_input An n x d data frame or matrix of the summary statistics z score or p value, n is the nubmer of genes, d is the number of data types. Each row is a gene, each column is a data type.
#' @param data_type Whether the input data is the p values or z scores, default is p value
#' @param mu_ini  Initial values for the mean of the independent mixture model distribution. A vector of length 2*d, d is number of data types. Needs to be in a special format: for example, if d=3, needs to be in the format of (null_1,alternative_1,null_2,alternative_2,null_3,alternative_3).
#' @param sigma_ini Initial values for the standard deviations of the two components in each data type. A vector of length 2*d, d is number of data types. Needs to be in a special format: for example, if d=3, needs to be in the format of (null_1,alternative_1,null_2,alternative_2,null_3,alternative_3).
#' @param p_ini Initial values for the proportion of the distribution of the two components in each data type. A vector of length 2*d, d is number of data types. Needs to be in a special format: for example, if d=3, needs to be in the format of (null_1,alternative_1,null_2,alternative_2,null_3,alternative_3).
#' @param tol The convergence criterion. Convergence is declared when the change in the observed data log-likelihood increases by less than epsilon.
#' @param maxiter The maximum number of iteration, default is 1000
#' @param seed Set.seed, default is 10
#' @param ini.ind Use the parameters estimated from IMIX-ind for initial values of other IMIX models, default is TRUE
#' @param model Which model to use to compute the data, default is all
#' @param model_selection_method Model selection information criteria, based on AIC or BIC, default is BIC
#' @param alpha Prespecified nominal level for global FDR control, default is 0.2
#' @param verbose Whether to print the full log-likelihood for each iteration, default is FALSE
#' @param sort_label Whether to sort the component labels in case component labels switched after convergence of the initial values, default is TRUE, notice that if the users chooose not to, they might need to check the interested IMIX model for the converged mean for the true component labels and perform the adaptive FDR control separately for an acurate result
#' @return The results of IMIX
#' @export

IMIX=function(data_input, #An n x d data frame or matrix of the summary statistics z score or p value, n is the nubmer of genes, d is the number of data types. Each row is a gene, each column is a data type.
              data_type=c("p","z"), #Whether the input data is the p values or z scores, default is p value
              mu_ini=NULL, #Initial values for the mean of the independent mixture model distribution. A vector of length 2*d, d is number of data types. Needs to be in a special format: for example, if d=3, needs to be in the format of (null_1,alternative_1,null_2,alternative_2,null_3,alternative_3).
              sigma_ini=NULL, #Initial values for the standard deviations of the two components in each data type. A vector of length 2*d, d is number of data types. Needs to be in a special format: for example, if d=3, needs to be in the format of (null_1,alternative_1,null_2,alternative_2,null_3,alternative_3).
              p_ini=NULL, #Initial values for the proportion of the distribution of the two components in each data type. A vector of length 2*d, d is number of data types. Needs to be in a special format: for example, if d=3, needs to be in the format of (null_1,alternative_1,null_2,alternative_2,null_3,alternative_3).
              tol=1e-6, #The convergence criterion. Convergence is declared when the change in the observed data log-likelihood increases by less than epsilon.
              maxiter=1000, #The maximum number of iteration, default is 1000
              seed=10,#set.seed, default is 10
              ini.ind=TRUE, #Use the parameters estimated from IMIX-ind for initial values of other IMIX models, default is TRUE
              model=c("all","IMIX_ind","IMIX_cor_twostep","IMIX_cor_restrict","IMIX_cor"), #Which model to use to compute the data, default is all
              model_selection_method=c("BIC","AIC"), #Model selection information criteria, based on AIC or BIC, default is BIC
              alpha=0.2, #Prespecified nominal level for global FDR control, default is 0.2
              verbose=FALSE, #Whether to print the full log-likelihood for each iteration, default is FALSE
              sort_label=TRUE #Whether to sort the component labels in case component labels switched after convergence of the initial values, default is TRUE, notice that if the users chooose not to, they might need to check the interested IMIX model for the converged mean for the true component labels and perform the adaptive FDR control separately for an acurate result
){
  data_type <- match.arg(data_type)
  if (data_type == "p") {
    data_input = apply(data_input, 2, function(x)
      qnorm(x, lower.tail = F))
  }
  
  model <- match.arg(model)
  model_selection_method <- match.arg(model_selection_method)
  
  g = 2 ^ (dim(data_input)[2]) #Number of components
  
  if (is.null(data_input) == TRUE) {
    cat(crayon::red("Error: Need a data matrix input!"))
    return(1)
  }
  
  cat(crayon::cyan$bold("Assign initial values\n"))
  
  
  if (dim(data_input)[2] == 3) {
    if(is.null(mu_ini) == TRUE) {mu_ini=c(0,3,0,3,0,3)}
    if(is.null(sigma_ini) == TRUE) {sigma_ini=rep(1,6)}
    if(is.null(p_ini) == TRUE) {p_ini=c(0.8,0.2,0.8,0.2,0.8,0.2)}
    
    
    fit1 = mixtools::normalmixEM(data_input[, 1], lambda=p_ini[1:2], mu=mu_ini[1:2], sigma=sigma_ini[1:2], k=2, maxit = maxiter)
    fit2 = mixtools::normalmixEM(data_input[, 2], lambda=p_ini[3:4], mu=mu_ini[3:4], sigma=sigma_ini[3:4], k=2, maxit = maxiter)
    fit3 = mixtools::normalmixEM(data_input[, 3], lambda=p_ini[5:6], mu=mu_ini[5:6], sigma=sigma_ini[5:6], k=2, maxit = maxiter)
    
    #########################################
    #Initial values based on single EM
    #########################################
    id_ini1=order(fit1$mu)
    id_ini2=order(fit2$mu)
    id_ini3=order(fit3$mu)
    
    mu1 = fit1$mu[id_ini1]
    mu2 = fit2$mu[id_ini2]
    mu3 = fit3$mu[id_ini3]
    mu_vec = list()
    mu_vec[[1]] = c(mu1[1], mu2[1], mu3[1])
    mu_vec[[2]] = c(mu1[2], mu2[1], mu3[1])
    mu_vec[[3]] = c(mu1[1], mu2[2], mu3[1])
    mu_vec[[4]] = c(mu1[1], mu2[1], mu3[2])
    mu_vec[[5]] = c(mu1[2], mu2[2], mu3[1])
    mu_vec[[6]] = c(mu1[2], mu2[1], mu3[2])
    mu_vec[[7]] = c(mu1[1], mu2[2], mu3[2])
    mu_vec[[8]] = c(mu1[2], mu2[2], mu3[2])
    
    sigma1 = fit1$sigma[id_ini1]
    sigma2 = fit2$sigma[id_ini2]
    sigma3 = fit3$sigma[id_ini3]
    
    cov = list()
    cov[[1]] = diag(x = c(sigma1[1], sigma2[1], sigma3[1]),
                    nrow = 3)
    cov[[2]] = diag(x = c(sigma1[2], sigma2[1], sigma3[1]),
                    nrow = 3)
    cov[[3]] = diag(x = c(sigma1[1], sigma2[2], sigma3[1]),
                    nrow = 3)
    cov[[4]] = diag(x = c(sigma1[1], sigma2[1], sigma3[2]),
                    nrow = 3)
    cov[[5]] = diag(x = c(sigma1[2], sigma2[2], sigma3[1]),
                    nrow = 3)
    cov[[6]] = diag(x = c(sigma1[2], sigma2[1], sigma3[2]),
                    nrow = 3)
    cov[[7]] = diag(x = c(sigma1[1], sigma2[2], sigma3[2]),
                    nrow = 3)
    cov[[8]] = diag(x = c(sigma1[2], sigma2[2], sigma3[2]),
                    nrow = 3)
    
    
    p1 = fit1$lambda[id_ini1]
    p2 = fit2$lambda[id_ini2]
    p3 = fit3$lambda[id_ini3]
    p = c(
      p1[1] * p2[1] * p3[1],
      p1[2] * p2[1] * p3[1],
      p1[1] * p2[2] * p3[1],
      p1[1] * p2[1] * p3[2],
      p1[2] * p2[2] * p3[1],
      p1[2] * p2[1] * p3[2],
      p1[1] * p2[2] * p3[2],
      p1[2] * p2[2] * p3[2]
    )
    
    
  } else if (dim(data_input)[2] == 2) {
    
    if(is.null(mu_ini) == TRUE) {mu_ini=c(0,3,0,3)}
    if(is.null(sigma_ini) == TRUE) {sigma_ini=rep(1,4)}
    if(is.null(p_ini) == TRUE) {p_ini=c(0.8,0.2,0.8,0.2)}
    
    fit1 = mixtools::normalmixEM(data_input[, 1], lambda=p_ini[1:2], mu=mu_ini[1:2], sigma=sigma_ini[1:2], k=2, maxit = maxiter)
    fit2 = mixtools::normalmixEM(data_input[, 2], lambda=p_ini[3:4], mu=mu_ini[3:4], sigma=sigma_ini[3:4], k=2, maxit = maxiter)
    
    
    #########################################
    #Initial values based on single EM
    #########################################
    
    id_ini1=order(fit1$mu)
    id_ini2=order(fit2$mu)
    
    mu1 = fit1$mu[id_ini1]
    mu2 = fit2$mu[id_ini2]
    
    mu_vec = list()
    mu_vec[[1]] = c(mu1[1], mu2[1])
    mu_vec[[2]] = c(mu1[2], mu2[1])
    mu_vec[[3]] = c(mu1[1], mu2[2])
    mu_vec[[4]] = c(mu1[2], mu2[2])
    
    
    sigma1 = fit1$sigma[id_ini1]
    sigma2 = fit2$sigma[id_ini2]
    
    cov = list()
    cov[[1]] = diag(x = c(sigma1[1], sigma2[1]),
                    nrow = 2)
    cov[[2]] = diag(x = c(sigma1[2], sigma2[1]),
                    nrow = 2)
    cov[[3]] = diag(x = c(sigma1[1], sigma2[2]),
                    nrow = 2)
    cov[[4]] = diag(x = c(sigma1[2], sigma2[2]),
                    nrow = 2)
    
    p1 = fit1$lambda[id_ini1]
    p2 = fit2$lambda[id_ini2]
    
    p = c(p1[1] * p2[1], p1[2] * p2[1], p1[1] * p2[2], p1[2] * p2[2])
    
    
  } else  {
    cat(crayon::red("Error: Function does not support the number of data types!"))
    return(1)
  }
  
  if (dim(data_input)[2] == 3) {
    mu_ini1 = c(mu_vec[[1]][1], mu_vec[[2]][1], mu_vec[[1]][2], mu_vec[[3]][2], mu_vec[[1]][3], mu_vec[[4]][3])
    sigma_ini1 = c(cov[[1]][1, 1], cov[[2]][1, 1], cov[[1]][2, 2], cov[[3]][2, 2], cov[[1]][3, 3], cov[[4]][3, 3])
  } else {
    mu_ini1 = c(mu_vec[[1]][1], mu_vec[[2]][1], mu_vec[[1]][2], mu_vec[[3]][2])
    sigma_ini1 = c(cov[[1]][1, 1], cov[[2]][1, 1], cov[[1]][2, 2], cov[[3]][2, 2])
    
  }
  
  
  
  
  #########################################
  #Start model fitting
  #########################################
  IMIX_ind_output = IMIX_ind(
    data_input,
    data_type = "z",
    mu = mu_ini1,
    sigma = sigma_ini1,
    p = p,
    tol = tol,
    maxiter = maxiter,
    seed = seed,
    verbose = verbose
  )
  if (model == "IMIX_ind") {
    IMIX_cor_twostep_output = NULL
    IMIX_cor_output = NULL
    IMIX_cor_restrict_output = NULL
  } else {
    if (dim(data_input)[2] == 3) {
      mu1 = IMIX_ind_output$mu[1:2]
      mu2 = IMIX_ind_output$mu[3:4]
      mu3 = IMIX_ind_output$mu[5:6]
      mu_vec_ind = list()
      mu_vec_ind[[1]] = c(mu1[1], mu2[1], mu3[1])
      mu_vec_ind[[2]] = c(mu1[2], mu2[1], mu3[1])
      mu_vec_ind[[3]] = c(mu1[1], mu2[2], mu3[1])
      mu_vec_ind[[4]] = c(mu1[1], mu2[1], mu3[2])
      mu_vec_ind[[5]] = c(mu1[2], mu2[2], mu3[1])
      mu_vec_ind[[6]] = c(mu1[2], mu2[1], mu3[2])
      mu_vec_ind[[7]] = c(mu1[1], mu2[2], mu3[2])
      mu_vec_ind[[8]] = c(mu1[2], mu2[2], mu3[2])
      
      sigma1 = IMIX_ind_output$sigma[1:2]
      sigma2 = IMIX_ind_output$sigma[3:4]
      sigma3 = IMIX_ind_output$sigma[5:6]
      cov_ind = list()
      cov_ind[[1]] = diag(x = c(sigma1[1], sigma2[1], sigma3[1]), nrow = 3)
      cov_ind[[2]] = diag(x = c(sigma1[2], sigma2[1], sigma3[1]), nrow = 3)
      cov_ind[[3]] = diag(x = c(sigma1[1], sigma2[2], sigma3[1]), nrow = 3)
      cov_ind[[4]] = diag(x = c(sigma1[1], sigma2[1], sigma3[2]), nrow = 3)
      cov_ind[[5]] = diag(x = c(sigma1[2], sigma2[2], sigma3[1]), nrow = 3)
      cov_ind[[6]] = diag(x = c(sigma1[2], sigma2[1], sigma3[2]), nrow = 3)
      cov_ind[[7]] = diag(x = c(sigma1[1], sigma2[2], sigma3[2]), nrow = 3)
      cov_ind[[8]] = diag(x = c(sigma1[2], sigma2[2], sigma3[2]), nrow = 3)
      
      
    } else {
      mu1 = IMIX_ind_output$mu[1:2]
      mu2 = IMIX_ind_output$mu[3:4]
      mu_vec_ind = list()
      mu_vec_ind[[1]] = c(mu1[1], mu2[1])
      mu_vec_ind[[2]] = c(mu1[2], mu2[1])
      mu_vec_ind[[3]] = c(mu1[1], mu2[2])
      mu_vec_ind[[4]] = c(mu1[2], mu2[2])
      
      sigma1 = IMIX_ind_output$sigma[1:2]
      sigma2 = IMIX_ind_output$sigma[3:4]
      cov_ind = list()
      cov_ind[[1]] = diag(x = c(sigma1[1], sigma2[1]), nrow = 2)
      cov_ind[[2]] = diag(x = c(sigma1[2], sigma2[1]), nrow = 2)
      cov_ind[[3]] = diag(x = c(sigma1[1], sigma2[2]), nrow = 2)
      cov_ind[[4]] = diag(x = c(sigma1[2], sigma2[2]), nrow = 2)
      
      
    }
    p_ind = IMIX_ind_output$pi
    if (ini.ind == TRUE) {
      if (model == "IMIX_cor_twostep") {
        IMIX_cor_twostep_output = IMIX_cor_twostep(
          data_input,
          data_type = "z",
          mu_vec = mu_vec_ind,
          cov = cov_ind,
          p = p_ind,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_restrict_output = NULL
        IMIX_cor_output = NULL
      } else if (model == "IMIX_cor") {
        IMIX_cor_output = IMIX_cor(
          data_input,
          data_type = "z",
          mu_vec = mu_vec_ind,
          cov = cov_ind,
          p = p_ind,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_restrict_output = NULL
        IMIX_cor_twostep_output = NULL
      } else if (model == "IMIX_cor_restrict") {
        IMIX_cor_restrict_output = IMIX_cor_restrict(
          data_input,
          data_type = "z",
          mu = IMIX_ind_output$mu,
          cov = cov_ind,
          p = p_ind,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_twostep_output = NULL
        IMIX_cor_output = NULL
      } else {
        IMIX_cor_twostep_output = IMIX_cor_twostep(
          data_input,
          data_type = "z",
          mu_vec = mu_vec_ind,
          cov = cov_ind,
          p = p_ind,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_output = IMIX_cor(
          data_input,
          data_type = "z",
          mu_vec = mu_vec_ind,
          cov = cov_ind,
          p = p_ind,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_restrict_output = IMIX_cor_restrict(
          data_input,
          data_type = "z",
          mu = IMIX_ind_output$mu,
          cov = cov_ind,
          p = p_ind,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        
      }
      
    } else {
      if (model == "IMIX_cor_twostep") {
        IMIX_cor_twostep_output = IMIX_cor_twostep(
          data_input,
          data_type = "z",
          mu_vec = mu_vec_ind,
          cov = cov,
          p = p,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_restrict_output = NULL
        IMIX_cor_output = NULL
      } else if (model == "IMIX_cor") {
        IMIX_cor_output = IMIX_cor(
          data_input,
          data_type = "z",
          mu_vec = mu_vec,
          cov = cov,
          p = p,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_twostep_output = NULL
        IMIX_cor_restrict_output = NULL
      } else if (model == "IMIX_cor_restrict") {
        IMIX_cor_restrict_output = IMIX_cor_restrict(
          data_input,
          data_type = "z",
          mu = mu_ini1,
          cov = cov,
          p = p,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_twostep_output = NULL
        IMIX_cor_output = NULL
      } else {
        IMIX_cor_twostep_output = IMIX_cor_twostep(
          data_input,
          data_type = "z",
          mu_vec = mu_vec_ind,
          cov = cov,
          p = p,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_output = IMIX_cor(
          data_input,
          data_type = "z",
          mu_vec = mu_vec,
          cov = cov,
          p = p,
          g = g,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        IMIX_cor_restrict_output = IMIX_cor_restrict(
          data_input,
          data_type = "z",
          mu = mu_ini1,
          cov = cov,
          p = p,
          tol = tol,
          maxiter = maxiter,
          seed = seed,
          verbose = verbose
        )
        
      }
    }
    
  }
  
  
  #########################################
  #Use AIC or BIC to select the best model
  #########################################
  #calculate AIC and BIC
  cat(crayon::cyan$bold("Start Model Selection\n"))
  best_model = NULL
  if (model == "all") {
    best_model = list(
      IMIX_ind_output,
      IMIX_cor_twostep_output,
      IMIX_cor_output,
      IMIX_cor_restrict_output
    )
    names(best_model) = c("IMIX_ind",
                          "IMIX_cor_twostep",
                          "IMIX_cor",
                          "IMIX_cor_restrict")
    model_selection_res = array(0, c(4, 2))
    for (i in 1:4) {
      model_selection_res[i, ] = model_selection(
        best_model[[i]]$`Full MaxLogLik final`,
        n = dim(data_input)[1],
        g = g,
        d = dim(data_input)[2],
        modelname = names(best_model)[i]
      )
    }
    rownames(model_selection_res) = names(best_model)
    colnames(model_selection_res) = c("AIC", "BIC")
    if (model_selection_method == "AIC") {
      id = which.min(model_selection_res[, 1])
      best_model_name = names(best_model)[id]
      best_model = best_model[[id]]
    } else {
      id = which.min(model_selection_res[, 2])
      best_model_name = names(best_model)[id]
      best_model = best_model[[id]]
    }
    
    
  } else if (model == "IMIX_cor") {
    best_model = IMIX_cor_output
    best_model_name = "IMIX_cor"
    model_selection_res = NULL
  } else if (model == "IMIX_cor_twostep") {
    best_model = IMIX_cor_twostep_output
    best_model_name = "IMIX_cor_twostep"
    model_selection_res = NULL
  } else if (model == "IMIX_cor_restrict") {
    best_model = IMIX_cor_restrict_output
    best_model_name = "IMIX_cor_restrict"
    model_selection_res = NULL
  } else {
    best_model = IMIX_ind_output
    best_model_name = "IMIX_ind"
    model_selection_res = NULL
  }
  
  
  
  #########################################
  #Classes based on posterior probability and the corresponding local FDR
  #########################################
  #In case the component labels switched after convergence of the initial values, we need to sort the labels
  
  if(sort_label==TRUE){
    if(dim(data_input)[2] == 2){
      
      mu_tmp=matrix(unlist(IMIX_cor_twostep_output$mu), nrow = 4, byrow = TRUE)
      min_mu1=min(mu_tmp[,1])
      max_mu1=max(mu_tmp[,1])
      min_mu2=min(mu_tmp[,2])
      max_mu2=max(mu_tmp[,2])
      
      sort_id=c(which(mu_tmp[,1] == min_mu1 & mu_tmp[,2] == min_mu2),which(mu_tmp[,1] == max_mu1 & mu_tmp[,2] == min_mu2),
                which(mu_tmp[,1] == min_mu1 & mu_tmp[,2] == max_mu2),which(mu_tmp[,1] == max_mu1 & mu_tmp[,2] == max_mu2))
      
      IMIX_cor_twostep_output$mu=IMIX_cor_twostep_output$mu[sort_id]
      IMIX_cor_twostep_output$cov=IMIX_cor_twostep_output$cov[sort_id]
      IMIX_cor_twostep_output$pi=IMIX_cor_twostep_output$pi[sort_id]
      IMIX_cor_twostep_output$`posterior prob`=IMIX_cor_twostep_output$`posterior prob`[,sort_id]
      colnames(IMIX_cor_twostep_output$`posterior prob`)=paste0("component",1:4)
      
      
      IMIX_cor_output$mu=IMIX_cor_output$mu[sort_id]
      IMIX_cor_output$cov=IMIX_cor_output$cov[sort_id]
      IMIX_cor_output$pi=IMIX_cor_output$pi[sort_id]
      IMIX_cor_output$`posterior prob`=IMIX_cor_output$`posterior prob`[,sort_id]
      colnames(IMIX_cor_output$`posterior prob`)=paste0("component",1:4)
      
      
      IMIX_cor_restrict_output$cov=IMIX_cor_restrict_output$cov[sort_id]
      IMIX_cor_restrict_output$pi=IMIX_cor_restrict_output$pi[sort_id]
      IMIX_cor_restrict_output$`posterior prob`=IMIX_cor_restrict_output$`posterior prob`[,sort_id]
      colnames(IMIX_cor_restrict_output$`posterior prob`)=paste0("component",1:4)
      
      
      IMIX_ind_output$pi=IMIX_ind_output$pi[sort_id]
      IMIX_ind_output$`posterior prob`=IMIX_ind_output$`posterior prob`[,sort_id]
      colnames(IMIX_ind_output$`posterior prob`)=paste0("component",1:4)
      
      
      mu_tmp=IMIX_ind_output$mu
      min_mu1=min(mu_tmp[c(1,2)])
      max_mu1=max(mu_tmp[c(1,2)])
      min_mu2=min(mu_tmp[c(3,4)])
      max_mu2=max(mu_tmp[c(3,4)])
      
      sort_id=c(which(mu_tmp[c(1,2)] == min_mu1),which(mu_tmp[c(1,2)] == max_mu1),
                which(mu_tmp[c(3,4)] == min_mu2)+2,which(mu_tmp[c(3,4)] == max_mu2)+2)
      
      IMIX_ind_output$mu=IMIX_ind_output$mu[sort_id]
      IMIX_ind_output$sigma=IMIX_ind_output$sigma[sort_id]
      
      IMIX_cor_restrict_output$mu=IMIX_cor_restrict_output$mu[sort_id]
    } else {
      mu_tmp=matrix(unlist(IMIX_cor_twostep_output$mu), nrow = 8, byrow = TRUE)
      min_mu1=min(mu_tmp[,1])
      max_mu1=max(mu_tmp[,1])
      min_mu2=min(mu_tmp[,2])
      max_mu2=max(mu_tmp[,2])
      min_mu3=min(mu_tmp[,3])
      max_mu3=max(mu_tmp[,3])
      
      sort_id=c(which(mu_tmp[,1] == min_mu1 & mu_tmp[,2] == min_mu2 & mu_tmp[,3] == min_mu3),which(mu_tmp[,1] == max_mu1 & mu_tmp[,2] == min_mu2 & mu_tmp[,3] == min_mu3),
                which(mu_tmp[,1] == min_mu1 & mu_tmp[,2] == max_mu2 & mu_tmp[,3] == min_mu3),which(mu_tmp[,1] == min_mu1 & mu_tmp[,2] == min_mu2 & mu_tmp[,3] == max_mu3),
                which(mu_tmp[,1] == max_mu1 & mu_tmp[,2] == max_mu2 & mu_tmp[,3] == min_mu3),which(mu_tmp[,1] == max_mu1 & mu_tmp[,2] == min_mu2 & mu_tmp[,3] == max_mu3),
                which(mu_tmp[,1] == min_mu1 & mu_tmp[,2] == max_mu2 & mu_tmp[,3] == max_mu3),which(mu_tmp[,1] == max_mu1 & mu_tmp[,2] == max_mu2 & mu_tmp[,3] == max_mu3)
      )
      
      IMIX_cor_twostep_output$mu=IMIX_cor_twostep_output$mu[sort_id]
      IMIX_cor_twostep_output$cov=IMIX_cor_twostep_output$cov[sort_id]
      IMIX_cor_twostep_output$pi=IMIX_cor_twostep_output$pi[sort_id]
      IMIX_cor_twostep_output$`posterior prob`=IMIX_cor_twostep_output$`posterior prob`[,sort_id]
      colnames(IMIX_cor_twostep_output$`posterior prob`)=paste0("component",1:8)
      
      
      IMIX_cor_output$mu=IMIX_cor_output$mu[sort_id]
      IMIX_cor_output$cov=IMIX_cor_output$cov[sort_id]
      IMIX_cor_output$pi=IMIX_cor_output$pi[sort_id]
      IMIX_cor_output$`posterior prob`=IMIX_cor_output$`posterior prob`[,sort_id]
      colnames(IMIX_cor_output$`posterior prob`)=paste0("component",1:8)
      
      
      IMIX_cor_restrict_output$cov=IMIX_cor_restrict_output$cov[sort_id]
      IMIX_cor_restrict_output$pi=IMIX_cor_restrict_output$pi[sort_id]
      IMIX_cor_restrict_output$`posterior prob`=IMIX_cor_restrict_output$`posterior prob`[,sort_id]
      colnames(IMIX_cor_restrict_output$`posterior prob`)=paste0("component",1:8)
      
      
      IMIX_ind_output$pi=IMIX_ind_output$pi[sort_id]
      IMIX_ind_output$`posterior prob`=IMIX_ind_output$`posterior prob`[,sort_id]
      colnames(IMIX_ind_output$`posterior prob`)=paste0("component",1:8)
      
      
      mu_tmp=IMIX_ind_output$mu
      min_mu1=min(mu_tmp[c(1,2)])
      max_mu1=max(mu_tmp[c(1,2)])
      min_mu2=min(mu_tmp[c(3,4)])
      max_mu2=max(mu_tmp[c(3,4)])
      min_mu3=min(mu_tmp[c(5,6)])
      max_mu3=max(mu_tmp[c(5,6)])
      
      sort_id=c(which(mu_tmp[c(1,2)] == min_mu1),which(mu_tmp[c(1,2)] == max_mu1),
                which(mu_tmp[c(3,4)] == min_mu2)+2,which(mu_tmp[c(3,4)] == max_mu2)+2,
                which(mu_tmp[c(5,6)] == min_mu3)+4,which(mu_tmp[c(5,6)] == max_mu3)+4)
      
      IMIX_ind_output$mu=IMIX_ind_output$mu[sort_id]
      IMIX_ind_output$sigma=IMIX_ind_output$sigma[sort_id]
      
      IMIX_cor_restrict_output$mu=IMIX_cor_restrict_output$mu[sort_id]
    }
    
    
    
  }
  
  
  class_before_controlFDR = apply(best_model$`posterior prob`, 1, which.max)
  localFDR_allgenes = 1 - apply(best_model$`posterior prob`, 1, max)
  
  
  #########################################
  #Adaptive procedure for global FDR control
  #########################################
  cat(crayon::cyan$bold("Start Adaptive FDR Control\n"))
  pred_group_adaptive = list()
  pred_group_adaptive_mFDR = list()
  pred_group_adaptive_twoclass = list()
  for (comp in 1:(g - 1)) {
    pred_fdr_twoclass = 1 - best_model$`posterior prob`[, (comp + 1)]
    names(pred_fdr_twoclass) = rownames(data_input)
    pred_group_adaptive[[comp]] = FDR_control_adaptive(lfdr = pred_fdr_twoclass, alpha =
                                                         alpha)
    pred_group_adaptive_mFDR[[comp]] = pred_group_adaptive[[comp]][[2]]
    pred_group_adaptive_twoclass[[comp]] = pred_group_adaptive[[comp]][[1]]
  }
  names(pred_group_adaptive_mFDR) = paste0("estimated_mFDR_comp", 2:g)
  
  sig_genes_all = array(0, c(dim(data_input)[1], 3))
  
  sig_genes_all[, 1] = localFDR_allgenes
  sig_genes_all[, 2] = class_before_controlFDR
  sig_genes_all[, 3] = 1
  
  rownames(sig_genes_all) = rownames(data_input)
  colnames(sig_genes_all) = c("localFDR", "class_withoutFDRcontrol", "class_FDRcontrol")
  
  for (comp in 1:(g - 1)) {
    sig_genes_all[which(pred_group_adaptive_twoclass[[comp]] == 1 & sig_genes_all[,2] == (comp+1) ), 3] = comp +
      1
  }
  
  sig_genes_all = data.frame(sig_genes_all)
  sig_genes_all = sig_genes_all[order(-sig_genes_all$class_FDRcontrol, sig_genes_all$localFDR), ]
  
  cat(crayon::cyan$bold("Finished!\n"))
  res = list(
    "IMIX_ind" = IMIX_ind_output,
    "IMIX_cor_twostep" = IMIX_cor_twostep_output,
    "IMIX_cor" = IMIX_cor_output,
    "IMIX_cor_restrict" = IMIX_cor_restrict_output,
    "AIC/BIC" = model_selection_res,
    "Selected Model" = best_model_name,
    "significant_genes_with_FDRcontrol" = sig_genes_all,
    "estimatedFDR" = pred_group_adaptive_mFDR,
    "alpha" = alpha
  )
}
