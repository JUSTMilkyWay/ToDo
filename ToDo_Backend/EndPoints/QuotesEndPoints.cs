using Microsoft.EntityFrameworkCore;
using ToDo_proj.Data;
using ToDo_proj.DTO;
using ToDo_proj.Models;
using System.Text.Json.Serialization;

namespace ToDo_proj.EndPoints;  


public static class QuotesEndPoints
{   
    public static void MapQuotesEndpoints(this WebApplication app)
    {   
        app.MapGet("/quotes/today", async (ToDoContext dbContext, HttpClient httpClient) =>
        {   
            DateOnly today = DateOnly.FromDateTime(DateTime.Now);

            var quoteDB = dbContext.Quotes.Where(t => t.TargetDate == today).FirstOrDefault();

            if (quoteDB is null)
            {
                return Results.NotFound(new QuoteDTO(Text : "DON`T FIND YOURSELF - CREATE", Author : "M_W"));
            }
            else
            {
                return Results.Ok(new QuoteDTO(
                    Text: quoteDB.Text.ToUpper(),
                    Author: quoteDB.Author
                ));
            }
        });
    }
}