using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();


builder.Services.AddDbContext<ShopDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<BarcodeService>();
builder.Services.AddScoped<EmployeeSalesService>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<ShopDbContext>();
        db.Database.Migrate();
    }
    catch (Exception ex)
    {
        // Written next to the app so it survives the crash
        File.WriteAllText(
            Path.Combine(AppContext.BaseDirectory, "startup-error.txt"),
            DateTime.UtcNow + Environment.NewLine + ex);
        // no 'throw': the site stays up so you can see the file
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI();
}



app.UseAuthorization();

app.MapControllers();

app.Run();
