library(simmer)
library(simmer.plot)

set.seed(123)
n_run <- 30   # Números de replicação para cada simulação
sim_t <- 7*960  # 7 dias (2 turnos)

# Criando uma funcao para simular um cenario
simular <- function(Punching,
                    Bending,
                    Welding,
                    Pressing,
                    Drilling){
  # Parametros a serem variados na simulacao
  Punching <- round(Punching, 0)
  Bending  <- round(Bending,  0)
  Welding  <- round(Welding,  0)
  Pressing <- round(Pressing, 0)
  Drilling <- round(Drilling, 0)
  # Criando ambiente de simulacao
  env <- simmer("model")
  # Definindo a trajetoria
  flowShop <- trajectory("flowShop") %>%
    ## add a Punching activity 
    seize("Punching", 1) %>%
    timeout(function() rnorm(1, 10)) %>%
    release("Punching", 1) %>%
    ## add a Bending activity
    seize("Bending", 1) %>%
    timeout(function() rnorm(1, 20)) %>%
    release("Bending", 1) %>%
    ## add a Welding activity
    seize("Welding", 1) %>%
    timeout(function() rnorm(1, 15)) %>%
    release("Welding", 1) %>%
    ## add a Pressing activity
    seize("Pressing", 1) %>%
    timeout(function() rnorm(1, 12)) %>%
    release("Pressing", 1) %>%
    ## add a Drilling activity
    seize("Drilling", 1) %>%
    timeout(function() rnorm(1, 6)) %>%
    release("Drilling", 1)
  # Adcionando recursos
  env %>%
    add_resource("Punching", Punching) %>%
    add_resource("Bending",  Bending ) %>%
    add_resource("Welding",  Welding ) %>%
    add_resource("Pressing", Pressing) %>%
    add_resource("Drilling", Drilling) %>%
    add_generator("flowShop", flowShop, function() rexp(1, 1/5))
  # Run com replicacoes
  envs <<- lapply(1:n_run, function(i) {
    reset(env) ; run(env, sim_t) # Simula tempo definido em sim_t
  })
  # Calculando a utilizacao media dos recursos
  util <- get_mon_resources(envs) %>%
    dplyr::group_by(.data$resource, .data$replication) %>%
    dplyr::mutate(dt = .data$time - dplyr::lag(.data$time)) %>%
    dplyr::mutate(in_use = .data$dt * dplyr::lag(.data$server / .data$capacity)) %>%
    dplyr::summarise(utilization = sum(.data$in_use, na.rm = TRUE) / sum(.data$dt, na.rm=TRUE)) %>%
    dplyr::summarise(utilization = mean(.data$utilization))
  # Retorna a utilização média dos recursos
  return(util[[2]] %>% mean)
}

library(GA)
library(parallel)

popSize <- 30         # Tamanho da população
maxiter <- 500        # Max de iteração
run <- 10             # Numero de iterações iguais que para otimização
pcrossover <- 0.8     # Crossover
pmutation <- 0.1      # Mutação
parallel <- TRUE      # Parelizando a avalição dos individuos

lower <- c(1,1,1,1,1) # Restrições de max
upper <- c(5,5,5,5,5) # Restrições de min

# Otimizacao em GA para encontrar a combinacao otima de recursos
GA <- ga(type = "real-valued",
         fitness = function(x) simular(x[1],x[2],x[3],x[4],x[5]),
         lower = lower,
         upper = upper,
         popSize = popSize,
         maxiter = maxiter,
         run = run,
         pcrossover = pcrossover,
         pmutation = pmutation,
         parallel = parallel)

# Melhor solucao
solution <- round(GA@solution) %>% print
plot(GA) # Plota busca

# Simula melhor solucao
do.call(simular, as.list(solution))
plot(get_mon_resources(envs)) # Plota resultados
