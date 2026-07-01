using ToDo_proj.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;

namespace ToDo_proj.Data;

public class ToDoContext : IdentityDbContext<IdentityUser>
{
    public ToDoContext(DbContextOptions<ToDoContext> options) : base(options) { }

    public DbSet<TaskToDo> Tasks => Set<TaskToDo>();

    public DbSet<Priority> Priorities => Set<Priority>();

    public DbSet<Quote> Quotes => Set<Quote>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);
    }
}