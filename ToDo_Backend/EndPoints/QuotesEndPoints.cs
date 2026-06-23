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

            if (quoteDB is not null)
            {
                return Results.Ok(new QuoteDTO(
                    Text: quoteDB.Text.ToUpper(),
                    Author: quoteDB.Author
                ));
            }
            else
            {
                string url = "https://zenquotes.io/api/random";
                HttpResponseMessage responseMessage = await httpClient.GetAsync(url);

                if (!responseMessage.IsSuccessStatusCode)
                {
                    return Results.BadRequest(responseMessage.StatusCode);
                }
                else
                {
                    try
                    {
                        var rawQuoteDTOs = await responseMessage.Content.ReadFromJsonAsync<List<RawQuoteDTO>>();

                        if (rawQuoteDTOs is not null)
                        {
                            Quote quoteCreated = new Quote{
                                Text = rawQuoteDTOs[0].Text.ToUpper(),
                                Author = rawQuoteDTOs[0].Author,
                                TargetDate = DateOnly.FromDateTime(DateTime.Today)
                            };

                            dbContext.Quotes.Add(quoteCreated);
                            await dbContext.SaveChangesAsync();
                            
                            QuoteDTO quoteDTO = new(
                                Text: quoteCreated.Text,
                                Author: quoteCreated.Author
                            );

                            return Results.Ok(quoteDTO);
                        }                       
                    }catch (Exception ex)
                    {
                        return Results.Problem(ex.GetHashCode().ToString());
                    }
                }
            }

            return Results.Ok(new QuoteDTO("YOU DON`T NEED TO FIND YOURSELF - CREATE", "M_W"));
        });
    }
}