using System;

namespace ToDo_proj.EndPoints;

public static class Testing
{
    public static void MapTesting(this WebApplication app)
    {
        var group = app.MapGroup("/testing");

        group.MapGet("/1", () => {
            return Results.Ok(DateOnly.FromDateTime(DateTime.Now));
        });
    }
}
