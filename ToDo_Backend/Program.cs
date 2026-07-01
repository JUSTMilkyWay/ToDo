using ToDo_proj.Data;
using ToDo_proj.EndPoints;
using ToDo_proj.Extensions;

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

builder.AddAuthAndIdentity();

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseCors();

app.MakeMigrations();

app.UseAuthentication();
app.UseAuthorization();

app.MapTasksEndpoints();
app.MapQuotesEndpoints();
app.MapAuthEndPoints();
app.MapTesting();

app.Run();