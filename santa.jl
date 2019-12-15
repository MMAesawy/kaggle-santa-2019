using DataFrames
using CSV
using Plots

const num_days = 100
const num_families = 5000

const gift_card_consolation = ([
    0.00,
    50.00,
    50.00,
    100.00,
    200.00,
    200.00,
    300.00,
    300.00,
    400.00,
    500.00,
    500.00
])

const santas_buffet_discount = ([
    0.00,
    0.00,
    0.25,
    0.25,
    0.25,
    0.50,
    0.50,
    1.00,
    1.00,
    1.00,
    1.00
])

const helicopter_discount = ([
    0,0,0,0,0,0,0,0,0,
    0.50,
    1.00
])

const buffet_value = 36.00
const helicopter_value = 398.00

const data = CSV.read("family_data.csv") |> Matrix{Int}

function preference_cost_family(choice::Int, family_count::Int)
    value_per_member = (buffet_value * santas_buffet_discount[choice]
                        + helicopter_value * helicopter_discount[choice])

    return gift_card_consolation[choice] + family_count * value_per_member
end # function

function preference_cost(choices::Array{Int, 1})
    return sum(map(preference_cost_family, choices, data[:, end]))
end # function

function accounting_penalty_daily(n_today::Int, n_yesterday::Int)
     return (n_today - 125) * n_today^(0.5 + abs(n_today - n_yesterday)/50)
 end # function

function accounting_penalty(N::Array{Int, 1})
    @assert(length(N) == num_days+1, "Invalid count vector length!")
    @assert(N[end] == N[end-1], "Invalid count vector!")
     return sum(map(accounting_penalty_daily, N[1:num_days], N[2:(num_days + 1)])) / 400
end # function

function get_count_vector(solution::Array{Int, 1})
    counts = zeros(Int, num_days + 1)
    for (i, assignment) in enumerate(solution)
        counts[assignment] += data[i, end]
    end # for
    counts[end] = counts[end-1]
    return counts
end # function

function get_choices(solution::Array{Int, 1})
    choices = ones(Int, num_families) .* 10
    for i = 1:num_families
        for j = 1:10
            if data[i, 1+j] == solution[i]
                choices[i] = j
                break
            end # if
        end # for
    end # for
    return choices
end # function

function objective(solution::Array{Int, 1})
    @assert(length(solution) == num_families, "Invalid solution vector count!")
    N = get_count_vector(solution)
    if !all(125 .<= N .<= 300) # solution is not feasible
        return -1
    end # if
    choices = get_choices(solution)

    total_cost = accounting_penalty(N) + preference_cost(choices)
    if total_cost < 0
        return typemax(Float64)
    else
        return total_cost
    end # if
end # function

function get_actual_solution(solution::Array{Int8, 1})
    return [data[i, 2+solution[i]] for i in 1:length(solution)]
end # function

function infeasibility_penalty_daily(n::Int)
    low = 125
    high = 300
    if n > high
        p = n - high
    elseif n < low
        p = low - n
    else
        p = 0
    end # if

    return (p*10000)^2.0
end # function

function infeasibility_penalty(N::Array{Int, 1})
    return sum(infeasibility_penalty_daily.(N[1:end-1]))
end # function

function objective_gradual(solution::Array{Int, 1})
    @assert(length(solution) == num_families, "Invalid solution vector count!")
    N = get_count_vector(solution)
    choices = get_choices(solution)
    acc = accounting_penalty(N)
    pref =  preference_cost(choices)
    #acc = 1
    total_cost =  pref + infeasibility_penalty(N)
    #total_cost = accounting_penalty(N) + infeasibility_penalty(N) + sum(choices.*10000)
    #total_cost = infeasibility_penalty(N)
    #total_cost = preference_cost(choices) + infeasibility_penalty(N)
    #total_cost = acc + infeasibility_penalty(N)
    if (acc < 0) | (acc > 10000)
        return typemax(Float64)
    else
        return total_cost
    end # if
    #return preference_cost(choices) + infeasibility_penalty(N)
end # function

function cut_pref!(solution::Array{Int8, 1})
    #solution = copy(solution)
    for w = maximum(solution):-1:1

        mask = solution .== w
        #best_cost = preference_cost(best .+ 1)
        best_cost = objective_gradual(get_actual_solution(solution))
        improvement = true
        j = 1
        while improvement
            #global best_cost, best, mask, j, improvement
            improvement = false
            for i in 1:length(mask)

                if mask[i]
                    solution[i] -= 1

                    actual_solution = get_actual_solution(solution)
                    #current_cost = preference_cost(best .+ 1)
                    current_cost = objective_gradual(actual_solution)

                    counts = get_count_vector(actual_solution)

                    if (!all(125 .<= counts .<= 300)) | (current_cost > best_cost)
                        solution[i] += 1
                        #mask[i] = false
                    else
                        mask[i] = false
                        improvement = true
                        best_cost = current_cost
                        @info j, current_cost
                    end # if
                end # if
            end # for
            j += 1
        end # while
    end # for
    return solution
end # function
#
# solution = CSV.read("sample_submission.csv") |> Matrix{Int}
# solution = solution[:,2]
#
# @time print(objective_gradual(data[:,3]))
#
#
#
# solution = data[:,2]
# solution[solution .== 1] = data[solution.==1,3]
# plot(get_count_vector(solution), seriestype=:bar)
# hline!([125, 300], linewidth=3)
