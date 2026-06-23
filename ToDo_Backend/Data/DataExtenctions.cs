using System;
using Microsoft.EntityFrameworkCore;
using ToDo_proj.Models;

namespace ToDo_proj.Data;

public static class DataExtenctions
{
    public static void MakeMigrations(this WebApplication app)
    {
        using var scope = app.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ToDoContext>();

        dbContext.Database.Migrate();
    }

    public static void Add_ToDoDb(this WebApplicationBuilder builder)
    {
        var connString = builder.Configuration.GetConnectionString("ToDo");
        builder.Services.AddSqlite<ToDoContext>(
            connString,
            optionsAction: options => options.UseSeeding((context, _) =>
            {   
                if (!context.Set<Priority>().Any())
                {
                    context.Set<Priority>().AddRange(
                        new Priority { Id = 1, Name = "LOW", HexColor = "#81C784" },
                        new Priority { Id = 2, Name = "MEDIUM", HexColor = "#FFFFB74D" },
                        new Priority { Id = 3, Name = "HIGH", HexColor = "#E57373" }
                    );

                    context.SaveChanges();
                } 
            })
        );
    }
}
