include("santa.jl")
using Plots
using Printf
using Statistics
using StatsBase: countmap
using StatsBase
using Random
using Base.Iterators

const bits_per_family = 2

function mutate_individual(solution::Array{Int8, 1}, pmute, pbitmute)
    if rand() < pmute
        mutation_mask = [sum(2 .^ (0:(bits_per_family-1)) .* (rand(bits_per_family) .< pbitmute)) for _ in 1:num_families]
        return solution .⊻ mutation_mask
    else
        return solution
    end # if
end # function

function crossover_pair(sol1::Array{Int8, 1}, sol2::Array{Int8, 1}, pcross, pflip)
    child1 = copy(sol1)
    child2 = copy(sol2)
    if rand() < pcross
        flip_mask = rand([0,1], num_families)
        # for i in 1:num_families
        #     if flip_mask[i] == 1
        #         child1[i], child2[i] = child2[i], child1[i]
        #     end # if
        # end # if
        #flip_mask = [sum(2 .^ (0:(bits_per_family-1)) .* (rand(bits_per_family) .< pflip)) for _ in 1:num_families]
        # child1 = (.~flip_mask .& child1) .| (flip_mask .& child2)
        # child2 = (.~flip_mask .& child2) .| (flip_mask .& child1)
        child1 = (flip_mask .* sol1) + ((1 .- flip_mask) .* sol2)
        child2 = (flip_mask .* sol2) + ((1 .- flip_mask) .* sol1)
        #crossover_point = rand(2:4999)
        #child1[1:crossover_point], child2[1:crossover_point] = child2[1:crossover_point], child1[1:crossover_point]
    end # if
    return hcat(child1, child2)
end # function

function tournament_selection(solutions::Array{Int8, 2}, fitnesses::Array{Float64, 1}, tournament_size::Int)
    selected = zeros(Int, length(fitnesses))
    selected[1:3] .= argmin(fitnesses)
    for i = 4:length(selected)
        contenders = rand(1:size(solutions, 2), tournament_size)
        selected[i] = Int(contenders[argmin(fitnesses[contenders])])
    end # for
    return solutions[:, selected]
end # function

function mutate_all!(solutions::Array{Int8, 2}, pmute, pbitmute)
    for i = 10:size(solutions, 2)
        solutions[:, i] = mutate_individual(solutions[:, i], pmute, pbitmute)
    end # for
    return solutions
end # function

function crossover_all!(solutions::Array{Int8, 2}, pcross, pflip)
    for i = 1:2:size(solutions, 2)
        solutions[:, [i, i+1]] = crossover_pair(solutions[:, i], solutions[:, i+1], pcross, pflip)
    end # for
end # function

function get_fitness(solution::Array{Int8, 1})
    return objective_gradual(get_actual_solution(solution))
end # function

function evaluate(solutions::Array{Int8, 2})
    return [get_fitness(solutions[:, i]) for i in 1:size(solutions, 2)]
end # function

function initial_solutions(population_size::Int)
    return rand(0:(2^bits_per_family-1), num_families, population_size)
end # function


const population_size = 10000
const num_generations = 10000
const tournament_size = 4
const pmute = 1.0
const pmuteflip = 0.0001
const pcross = 0.4
const pcrossflip = 0.5

#solutions = solutions[:, 1:50]
solutions = initial_solutions(population_size)
solutions = zeros(Int8, num_families, population_size)
sol = copy(solutions)
solutions[:,1:1000] = sol
solutions[:, 1:10] .= best
solutions = Int8.(solutions)
solutions[:, 1:1000] .= choices

best_solution = zeros(Int8, (size(solutions, 1), num_generations))
best_solution_fitness = zeros(num_generations)

fitnesses = evaluate(solutions)
for gen in 1:num_generations
    global solutions, best_solution, best_solution_fitness, fitnesses
    ran = shuffle(1:size(solutions, 2))
    solutions = solutions[:, ran]
    fitnesses = fitnesses[ran]
    solutions = tournament_selection(solutions, fitnesses, tournament_size)
    crossover_all!(solutions, pcross, pcrossflip)
    mutate_all!(solutions, pmute, pmuteflip)
    fitnesses = evaluate(solutions)
    best_individual = argmin(fitnesses)
    best_fitness = fitnesses[best_individual]
    solutions[:,best_individual] = cut_pref!(solutions[:,best_individual])
    best_solution[:, gen] = solutions[:, best_individual]
    best_solution_fitness[gen] = best_fitness
    if best_fitness == 0
        break
    end # if
    @info @sprintf("Generation %d: Best fitness: %.5f", gen, best_fitness)
end # for
best = solutions[:,1]
best = best_solution[:,argmin(best_solution_fitness[1:4000])]

actual_solution = get_actual_solution(best)
N = get_count_vector(actual_solution)
@printf("%.3f\n", objective(actual_solution))
@printf("%.3f\n", objective_gradual(actual_solution))
println(maximum(N))
println(minimum(N))
plot(best_solution_fitness)

CSV.write("best_constrained_2.csv", DataFrame(best[:,:]))
CSV.write("best_solution.csv", DataFrame(actual_solution[:,:]))
CSV.write("solutions_constrained_2.csv", DataFrame(solutions[:,1:1000]))

# solutions = (CSV.read("solutions_constrained.csv") |> Matrix{UInt8}) |> Array
# best = (CSV.read("best_constrained_2.csv") |> Matrix{Int})[:,1] |> Array
# choices = (CSV.read("best_preference_feasible.csv") |> Matrix{Int})[:,1] |> Array

# plot(N[1:end-1], seriestype=:bar)
# hline!([125, 300], linewidth=1)
# countmap(choices)
