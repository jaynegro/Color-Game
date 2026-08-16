--!strict

local Results = {}

function Results.Run(context, results: { string })
	local report = context.TableService.Resolve(results)
	context.Network.FireAll("Results", context.RoundId, results, report)
	context.RoundDisplayService.ShowResults()
	task.wait(context.Config.ResultDuration)
end

return Results
