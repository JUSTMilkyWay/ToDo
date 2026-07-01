using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace ToDo_proj.EndPoints;

public static class AuthEndpoints
{
    public static void MapAuthEndPoints(this WebApplication app)
    {
        app.MapPost("/register", async (UserManager<IdentityUser> userManager, IConfiguration config, [FromBody] RegisterDTO model) =>
        {
            var userExists = await userManager.FindByEmailAsync(model.Email);
            if (userExists != null) return Results.BadRequest("User already exists.");

            var user = new IdentityUser { UserName = model.Username, Email = model.Email };
            var result = await userManager.CreateAsync(user, model.Password);

            if (!result.Succeeded) return Results.BadRequest(result.Errors);

            var token = GenerateJwtToken(user, config);
            return Results.Ok(new AuthResponseDTO(token, user.Email!, user.UserName!));
        });

        app.MapPost("/login", async (UserManager<IdentityUser> userManager, IConfiguration config, [FromBody] LoginRequestDTO model) =>
        {
            var user = await userManager.FindByEmailAsync(model.Email);
            if (user == null || !await userManager.CheckPasswordAsync(user, model.Password))
            {
                return Results.BadRequest("Invalid email or password.");
            }

            var token = GenerateJwtToken(user, config);
            return Results.Ok(new AuthResponseDTO(token, user.Email!, user.UserName!));
        });
    }

    private static string GenerateJwtToken(IdentityUser user, IConfiguration config)
    {
        var jwtSettings = config.GetSection("Jwt");
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings["Key"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Email, user.Email!),
            new Claim(ClaimTypes.Name, user.UserName!)
        };

        var token = new JwtSecurityToken(
            issuer: jwtSettings["Issuer"],
            audience: jwtSettings["Audience"],
            claims: claims,
            expires: DateTime.Now.AddDays(7),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

public record RegisterDTO(string Email, string Username, string Password);
public record LoginRequestDTO(string Email, string Password);
public record AuthResponseDTO(string Token, string Email, string Username);