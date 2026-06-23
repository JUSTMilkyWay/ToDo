using System;
using Microsoft.EntityFrameworkCore;
using ToDo_proj.Data;
using ToDo_proj.DTO;
using ToDo_proj.Models;

namespace ToDo_proj.EndPoints;

public static class TasksEndPoints
{
    const string GetTasksEndpointsName = "GetTasks";

    public static void MapTasksEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/tasks");

        //GET + Date, if no date gives all from today
        group.MapGet("/", async (DateOnly? date, ToDoContext dbContext) =>
        {
            var targetDate = date ?? DateOnly.FromDateTime(DateTime.UtcNow);

            var tasksToday = await dbContext.Tasks
                .Where(t => t.Date == targetDate)
                .OrderBy(t => t.DayOrder)
                .Include(task => task.Priority)
                .Select(task => new SummaryToDoDTO(
                    task.Id,    
                    task.Name,
                    task.IsCompleted,
                    task.Description,
                    task.Priority!.Name,
                    task.Priority!.HexColor,

                    task.DayOrder,
                    task.Date,
                    task.DateCreated
                )).ToListAsync();

            return Results.Ok(tasksToday);
        });

        //GET - all
        group.MapGet("/all", async (ToDoContext dbContext) =>
            await dbContext.Tasks
                                .Include(task => task.Priority)
                                .Select(task => new SummaryToDoDTO(
                                        task.Id,    
                                        task.Name,
                                        task.IsCompleted,
                                        task.Description,
                                        task.Priority!.Name,
                                        task.Priority!.HexColor,

                                        task.DayOrder,
                                        task.Date,
                                        task.DateCreated
                                ))
                                .AsNoTracking()
                                .ToListAsync());

        //GET+Id
        group.MapGet("/{id}", async (int id, ToDoContext dbContext) =>
        {
           var task = await dbContext.Tasks.FindAsync(id);

           return task is null ? Results.NotFound() : Results.Ok(new InfoToDoDTO(
                id,
                task.Name,
                task.IsCompleted,
                task.Description,
                task.PriorityId,
                task.DayOrder,
                task.Date,
                task.DateCreated
           )); 
        }).WithName(GetTasksEndpointsName);

        //GET list of completed status of tasks for selected week 
        group.MapGet("/on_week_status", async (DateOnly startWeekDay, ToDoContext dbContext) =>
        {
            DateOnly endWeekDay = startWeekDay.AddDays(7);

            //Get all tasks for week range from bd, if they are there
            var dbWeekRange = await dbContext.Tasks
                .Where(t => t.Date >= startWeekDay && t.Date <= endWeekDay)
                .GroupBy(t => t.Date)
                .Select(task => new
                {
                    Date = task.Key,
                    CompletedCount = task.Count(t=> t.IsCompleted),
                    UnCompletedCount = task.Count(t => !t.IsCompleted)
                }).ToListAsync();
            
            var weekRangeDict = dbWeekRange.ToDictionary(x => x.Date);

            var result = new List<object>();
            for (int i = 0; i <= 6; i++)
            {
                var curentDate = startWeekDay.AddDays(i);

                if (weekRangeDict.TryGetValue(curentDate, out var dayInfo))
                {
                    result.Add(new
                    {
                        Date = curentDate,
                        CompletedTasks = dayInfo.CompletedCount,
                        UnCompletedTasks = dayInfo.UnCompletedCount
                    });
                }
                else
                {
                    result.Add(new
                    {
                        Date = curentDate,
                        CompletedTasks = 0,
                        UnCompletedTasks = 0
                    });
                }
            }

            return Results.Ok(result);
        });


        //POST
        group.MapPost("/", async (CreateToDoDTO createToDoDTO, ToDoContext dbContext) =>
        {
            TaskToDo taskToDo = new TaskToDo
            {
                Name = createToDoDTO.Name,
                Description = createToDoDTO.Description,
                PriorityId = createToDoDTO.PriorityId,
                DayOrder = createToDoDTO.DayOrder,
                Date = createToDoDTO.Date,
            };

            dbContext.Tasks.Add(taskToDo);
            await dbContext.SaveChangesAsync();

            InfoToDoDTO infoToDoDTO = new(
                taskToDo.Id,
                taskToDo.Name,
                taskToDo.IsCompleted,
                taskToDo.Description,
                taskToDo.PriorityId,
                taskToDo.DayOrder,
                taskToDo.Date,
                taskToDo.DateCreated
            );

            return Results.CreatedAtRoute(GetTasksEndpointsName, new {id = infoToDoDTO.Id}, infoToDoDTO);
        });

        //PUT
        group.MapPut("/{id}", async (int id, UpdateToDoDTO updatedTaskDTO, ToDoContext dbContext) =>
        {
            var taskId = await dbContext.Tasks.FindAsync(id);

            if (taskId is null)
            {
                return Results.NotFound();
            }

            taskId.Name = updatedTaskDTO.Name;
            taskId.IsCompleted = updatedTaskDTO.IsCompleted;
            taskId.Description = updatedTaskDTO.Description ?? string.Empty;
            taskId.PriorityId = updatedTaskDTO.PriorityId;
            taskId.DayOrder = updatedTaskDTO.DayOrder;
            taskId.Date = updatedTaskDTO.Date;

            await dbContext.SaveChangesAsync();
            
            return Results.NoContent();
        });

        //PATCH - change complete status by id
        group.MapPatch("/{id}/complete_status_toggle", async (int id, ToDoContext dbContext) =>
        {
            var task = await dbContext.Tasks.FindAsync(id);
            
            if (task is null)
            {
                return Results.NotFound();
            }
            task.IsCompleted = !task.IsCompleted;
            await dbContext.SaveChangesAsync();

            return Results.NoContent();
        });

        //DELETE
        group.MapDelete("/{id}", async (int id, ToDoContext dbContext) =>
        {   
            int rowsDeleted = await dbContext.Tasks.Where(task => task.Id == id).ExecuteDeleteAsync();

            return rowsDeleted == 0? Results.NotFound() : Results.NoContent();
        });
    }
}