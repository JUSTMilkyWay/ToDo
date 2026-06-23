using ToDo_proj.Data;
using ToDo_proj.EndPoints;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod() 
              .AllowAnyHeader();
    });
});

builder.Services.AddValidation();
builder.Services.AddHttpClient();
builder.Add_ToDoDb();

var app = builder.Build();

app.UseCors();

app.MakeMigrations();

app.MapTasksEndpoints();
app.MapQuotesEndpoints();
app.MapTesting();

app.Run();