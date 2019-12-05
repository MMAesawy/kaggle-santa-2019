using DataFrames
using CSV

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
     return sum(map(accounting_penalty_daily, N[1:num_days], N[2:(num_days + 1)])) / 400
end # function

function get_count_vector(solution)
    counts = zeros(Int, num_days + 1)
    for (i, assignment) in enumerate(solution)
        counts[assignment] += data[i, end]
    end # for
    return counts
end # function

function get_choices(solution)
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

function objective(solution)
    @assert(length(solution) == num_families, "Invalid solution vector count!")
    N = get_count_vector(solution)
    if !all(125 .<= N .<= 300) # solution is not feasible
        return -1
    end # if
    choices = get_choices(solution)

    return accounting_penalty(N) + preference_cost(choices)
end # function

solution = CSV.read("sample_submission.csv") |> Matrix{Int}
solution = solution[:,2]

@time print(objective(data[:,3]))



solution = data[:,2]
solution[solution .== 1] = data[solution.==1,3]
plot(get_count_vector(solution), seriestype=:bar)
hline!([125, 300], linewidth=3)
