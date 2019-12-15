include("santa.jl")
#include("genetic.jl")
using Printf
using Random
using StatsBase

function get_diff(n::Int)
    if n > 300
        return n - 300
    elseif n < 125
        return n - 125
    else
        return 0
    end # if
end # function

function get_deficit(counts::Array{Int, 1})
    return get_diff.(counts)
end # function

function select_day(deficits::Array{Int, 1})
    selected = argmax(deficits)
    if deficits[selected] == 0
        selected = argmin(deficits)
    end # if
    return selected
end # function


function bin_to_target(choices::Array{Int, 1}, N::Array{Int, 1}, solution::Array{Int, 1}, day::Int, target::Int)
    # if target >= 300
    #     target = 300
    # elseif target <= 125
    #     target = 125
    # end # if
    if target < N[day]
        family_mask = solution .== day
        families = family_sizes[family_mask, :]
        families = sortslices(families; dims=1,  lt=(x,y) -> isless(x[2], y[2]))
        sum_on_day = 0
        #print(length(families))
        for fam in 1:size(families, 1)
            sum_on_day += families[fam, 2]
            if sum_on_day > target
                choices[families[fam, 1]+1] += 1
            end # if
        end # for
    elseif target > N[day]
        family_mask = solution .!= day
        families = family_sizes[family_mask, :]
        families = sortslices(families; dims=1,  lt=(x,y) -> isless(x[2], y[2]), rev=true)
        sum_on_day = N[day]
        #print(length(families))
        choice_thresh = 1
        while sum_on_day < target
            for fam in 1:size(families, 1)
                family_idx = families[fam, 1]+1
                for c in 1:choice_thresh
                    if data[family_idx, 1+c] == day
                        choices[family_idx] = c - 1
                        sum_on_day += data[family_idx, end]
                    end # if
                end # for
            end # for
            choice_thresh += 1
            if choice_thresh > 10
                break
            end # if
        end # while
    end # if
    return choices
end # function

function exchanger(base_solution::Array{Int, 1})


    current_score = objective_gradual(base_solution)
    count = 0
    while true
        count += 1
        best_improvement = -1
        best_swap = (0, 0)
        for j in 1:(num_families-1)
            @info j
            for i in (j+1):num_families
                new_solution = copy(base_solution)
                new_solution[i], new_solution[j] = new_solution[j], new_solution[i]
                new_score = objective_gradual(new_solution)
                improvement = current_score - new_score
                if 0 < improvement < best_improvement
                    best_swap = (i, j)
                end # if
            end # for
        end # for
        if best_improvement <= 0
            break
        end # if
        @info @sprintf("Iteration %d: Improvement: %.2f", count, best_improvement)
        base_solution[best_swap[1]], base_solution[best_swap[2]] = base_solution[best_swap[2]], base_solution[best_swap[1]]
        current_score = objective_gradual(base_solution)
    end # while
    return base_solution
end # function

function best_fit(choices::Array{Int, 1})
    for i in 1:100
        solution = get_actual_solution(choices)
        N = get_count_vector(solution)
        choices = bin_to_target(choices, N, solution, i, N[i])
    end
    return choices
end




best = best_fit(best)

countmap(choices)
(5000-3871) * 50

N = get_count_vector(get_actual_solution(choices))
heat = map(accounting_penalty_daily, N[1:end-1], N[2:end])
bar(heat)

N = get_count_vector(get_actual_solution(choices))
plot(N[1:end-1], seriestype=:bar)
hline!([125, 300], linewidth=1)

log10(objective_gradual(get_actual_solution(choices)))
accounting_penalty(N)
preference_cost(choices .+ 1)


function increment_proposal!(proposal::Array{Int, 1}, k)
    proposal[end] += 1
    proposal[end] %= k
    for i in (length(proposal)-1):-1:1
        proposal[i] += (proposal[i+1] == 0)
        proposal[i] %= k
    end # for
    return proposal
end # function

function local_search(choices::Array{Int, 1}; iter=10000, n=6, k=4)
    try
        choices = copy(choices)
        best_choices = choices
        best_score = objective_gradual(get_actual_solution(choices))
        for i in 1:iter
            @info @sprintf("Iteration %d: Best score %.5f", i, log10(best_score))
            chosen_families = sample(1:length(choices), n, replace=false)
            current_proposal = [0 for _ in 1:n]
            for j in 1:(k^n)
                choices[chosen_families] = current_proposal
                new_score = objective_gradual(get_actual_solution(choices))
                if new_score < best_score
                    best_score = new_score
                    best_choices = copy(choices)
                    @info @sprintf("\tImproved to: %.5f", log10(best_score))
                end # if
                increment_proposal!(current_proposal, k)
            end # for
            choices = copy(best_choices)
        end # for
    finally
        return best_choices
    end # try
end # function


function best_fit(choices::Array{Int, 1})
    for i in 1:100
        choices = resort_families(choices, i)
    end
    return choices
end


function resort_families(choices::Array{Int, 1}, day)
    solution = get_actual_solution(choices)
    N = get_count_vector(solution)
    target = N[day]
    family_mask = solution .== day

    sum_on_day = 0
    zero_families = data[data[:,2] .== day, 1] .+ 1

    zero_families = sort(zero_families; lt=(x,y) -> data[x,end] < data[y, end])
    choices[family_mask] .+= 1
    solution = get_actual_solution(choices)
    for fam in zero_families
        if sum_on_day < target
            choices[fam] = 0
            solution[fam] = day
            sum_on_day += data[fam, end]
        else
            break
        end # if
    end # for
    if sum_on_day < target
        for c in 3:9
            other_families = data[data[:,c] .== day, 1] .+ 1
            other_families = sort(zero_families; lt=(x,y) -> data[x,end] < data[y, end], rev=true)
            for fam in other_families
                if sum_on_day < target
                    choices[fam] = c
                    solution[fam] = day
                    sum_on_day += data[fam, end]
                else
                    break
                end # if
            end # for
        end #for
    end # if
    return choices
end # function

function lt_family(x, y, out)
    if choices[x+1] == choices[y+1]
        return data[x, end] < data[y, end]
    elseif !out
        return choices[x+1] > choices[y+1]
    else
        return choices[x+1] < choices[y+1]
    end # if
end # function

function more_or_less(today, yesterday, now)
    k = 5
    x1 = accounting_penalty_daily(today, now) + accounting_penalty_daily(now, yesterday)
    x2 = accounting_penalty_daily(today, now+k) + accounting_penalty_daily(now+k, yesterday)
    x3 = accounting_penalty_daily(today, now-k) + accounting_penalty_daily(now-k, yesterday)
    x = [x1, x2, x3]
    y = [now, now+k, now-k]
    return y[argmin(x)]
end # function

function route(solution::Array{Int, 1})
    #solution = get_actual_solution(choices)
     # for _ in 1:1000
        movements = zeros(Int, (100, 100))
        candidates = zeros(Int, (100, 100))
        N = get_count_vector(solution)
        #optimals = [N[1], [optimal_pop[N[i-1]-124, N[i+1]-124] for i in 2:100]...]
        optimals = [N[1], [more_or_less(N[i-1], N[i+1], N[i]) for i in 2:100]...]
        N = N[1:end-1]
        excess = N .- optimals
        for i in 1:100
            mask = (solution .== i) .& (choices .!= 0)
            if any(mask) & (excess[i] != 0)
                families = sort(data[mask, 1], lt=(x,y) -> lt_family(x, y, excess[i] > 0), rev=true)
                for f in families
                    f += 1
                    f_size = data[f, end]
                    if (N[i]-f_size >= 125)
                        family_choice = data[f, 1 + (choices[f])]
                        if (candidates[i, family_choice] == 0) && (N[family_choice] + f_size <= 300) && (family_choice != i)
                            #println((N[family_choice] + f_size) > 300)
                            candidates[i, family_choice] = f
                            movements[i, family_choice] = f_size
                        end # if
                    end # if
                end # for
            end # if
        end # for
        return movements, candidates
    #     change = false
    #     heat = map(accounting_penalty_daily, N[1:end-1], N[2:end])
    #     i = argmax(heat)
    #     while ((excess[i] > 0) && !any(candidates[i,:] .!= 0)) || ((excess[i] < 0) && !any(candidates[:, i] .!= 0))
    #         heat[i] = 0
    #         i = argmax(heat)
    #     end # while
    #     println(N[i], ' ', optimals[i])
    #     if excess[i] > 0
    #         j = argmax(movements[i, :])
    #         #print(N[j] + data[c[i,j], end])
    #         solution[candidates[i,j]] = j
    #         change = true
    #         println(1,' ',candidates[i,j],' ', i,' ', j)
    #     elseif excess[i] < 0
    #         j = argmax(movements[:, i])
    #         #print(N[i] + data[c[j,i], end])
    #         solution[candidates[j,i]] = i
    #         change = true
    #         println(2,' ',candidates[i,j],' ', j,' ', i)
    #     end # if
    #     if !change
    #         break
    #     end # if
    #     @info objective_gradual(solution)
    # end # for
end # function

function get_optimal_at_each_step()
    optimal_pop = zeros(Int, (176, 176))
    for i in 125:300
        global optimal_pop
        for j in 125:300
            min_acc = Inf
            for k in 300:-1:125
                acc = accounting_penalty_daily(i, k) + accounting_penalty_daily(k, j)
                if acc <= min_acc
                    min_acc = acc
                    optimal_pop[i-124, j-124] = k
                end # if
            end # for
        end # for
    end # for
    return optimal_pop
end # function
