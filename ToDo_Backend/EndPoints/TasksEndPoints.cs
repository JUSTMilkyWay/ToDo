    using System;
    using System.Security.Claims;
    using Microsoft.AspNetCore.Mvc;
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
            var group = app.MapGroup("/tasks").RequireAuthorization();

            //GET + Date, if no date gives all from today
            group.MapGet("/", async (DateOnly? date, ToDoContext dbContext, ClaimsPrincipal user) =>
            {   
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                var targetDate = date ?? DateOnly.FromDateTime(DateTime.UtcNow);

                var tasksToday = await dbContext.Tasks
                    .Where(t => t.UserId == userId && t.Date == targetDate)
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
            group.MapGet("/all", async (ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                var userTasks = await dbContext.Tasks
                                    .Include(task => task.Priority)
                                    .Where(t => t.UserId == userId)
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
                                    .ToListAsync();

                return Results.Ok(userTasks);
            });

            //GET+Id
            group.MapGet("/{id}", async (int id, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                var task = await dbContext.Tasks.FirstOrDefaultAsync(t => t.UserId == userId && t.Id == id);

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
            group.MapGet("/on_week_status", async (DateOnly startWeekDay, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                DateOnly endWeekDay = startWeekDay.AddDays(6);

                //Get all tasks for week range from bd, if they are there
                var dbWeekRange = await dbContext.Tasks
                    .Where(t => t.UserId == userId && t.Date >= startWeekDay && t.Date <= endWeekDay)
                    .GroupBy(t => t.Date)
                    .Select(task => new
                    {
                        Date = task.Key,
                        CompletedCount = task.Count(t => t.IsCompleted),
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
            group.MapPost("/", async (CreateToDoDTO createToDoDTO, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                int curentTaskCount = await dbContext.Tasks
                                .Where(t => t.UserId == userId && t.Date == createToDoDTO.Date)
                                .CountAsync();

                TaskToDo taskToDo = new TaskToDo
                {
                    Name = createToDoDTO.Name,
                    Description = createToDoDTO.Description,
                    PriorityId = createToDoDTO.PriorityId,
                    DayOrder = curentTaskCount + 1,
                    Date = createToDoDTO.Date,
                    UserId = userId
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
            group.MapPut("/{id}", async (int id, UpdateToDoDTO updatedTaskDTO, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                var taskId = await dbContext.Tasks.FirstOrDefaultAsync(t => t.UserId == userId && t.Id == id);

                if (taskId is null)
                {
                    return Results.NotFound();
                }

                taskId.Name = updatedTaskDTO.Name;
                taskId.IsCompleted = updatedTaskDTO.IsCompleted;
                taskId.Description = updatedTaskDTO.Description ?? string.Empty;
                taskId.PriorityId = updatedTaskDTO.PriorityId;
                taskId.Date = updatedTaskDTO.Date;

                await dbContext.SaveChangesAsync();
                
                return Results.NoContent();
            });

            //PATCH - change complete status by id
            group.MapPatch("/{id}/complete_status_toggle", async (int id, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                var task = await dbContext.Tasks.FirstOrDefaultAsync(t => t.UserId == userId && t.Id == id);
                
                if (task is null)
                {
                    return Results.NotFound();
                }
                bool willBeCompleted = !task.IsCompleted;

                if (willBeCompleted == true)
                {
                    int taskOrder = task.DayOrder;

                    var tasksBelow = await dbContext.Tasks.Where(t=> t.Date == task.Date && t.DayOrder > taskOrder && t.IsCompleted == false).ToListAsync();

                    foreach (var task_below in tasksBelow)
                    {
                        task_below.DayOrder -= 1;
                    }

                    task.DayOrder = -1;
                }
                else
                {
                    int lastOrderCompleted = await dbContext.Tasks.Where(t => t.UserId == userId && t.Date == task.Date && t.IsCompleted == false).CountAsync();

                    task.DayOrder = lastOrderCompleted + 1;
                }
                task.IsCompleted = willBeCompleted;
                await dbContext.SaveChangesAsync();

                return Results.NoContent();
            });

            // PATCH - move task up/down in day order
            group.MapPatch("/{id}/move", async (int id, [FromBody] int deltaOrderInt, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();

                var task = await dbContext.Tasks.FirstOrDefaultAsync(t => t.UserId == userId && t.Id == id);
                if (task is null)
                {
                    return Results.NotFound();
                }

                if (task.IsCompleted)
                {
                    return Results.BadRequest("Cannot move completed tasks.");
                }
                
                var taskLower = await dbContext.Tasks
                                    .Where(t => t.UserId == userId && t.Date == task.Date && t.DayOrder == task.DayOrder + deltaOrderInt)
                                    .FirstOrDefaultAsync();

                if (taskLower is null)
                {
                    return Results.NoContent(); 
                }

                int newOrder = task.DayOrder + deltaOrderInt;
                
                task.DayOrder = newOrder;
                taskLower.DayOrder = newOrder - deltaOrderInt;

                await dbContext.SaveChangesAsync();

                return Results.NoContent();
            });

            //DELETE
            group.MapDelete("/{id}", async (int id, ToDoContext dbContext, ClaimsPrincipal user) =>
            {
                var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;

                if (userId is null) return Results.Unauthorized();
                
                var task = await dbContext.Tasks.FirstOrDefaultAsync(t => t.UserId == userId && t.Id == id);
                if (task is null)
                {
                    return Results.NotFound();
                }

                if (task.IsCompleted == false)
                {
                    int taskOrder = task.DayOrder;

                    var tasksBelow = await dbContext.Tasks.Where(t => t.UserId == userId && t.Date == task.Date && t.DayOrder > taskOrder && t.IsCompleted == false).ToListAsync();

                    foreach (var task_below in tasksBelow)
                    {
                        task_below.DayOrder -= 1;
                    }

                    task.DayOrder = -1;
                }
                
                dbContext.Tasks.Remove(task);
                await dbContext.SaveChangesAsync();

                return Results.NoContent();
            });
        }
    }