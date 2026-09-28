using System.Data.Common;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace SummerLandBackend.Data
{
    public sealed class SqliteBusyTimeoutInterceptor : DbConnectionInterceptor
    {
        private const string BusyTimeoutSql = "PRAGMA busy_timeout = 30000;";

        public override void ConnectionOpened(
            DbConnection connection,
            ConnectionEndEventData eventData)
        {
            SetBusyTimeout(connection);
            base.ConnectionOpened(connection, eventData);
        }

        public override Task ConnectionOpenedAsync(
            DbConnection connection,
            ConnectionEndEventData eventData,
            CancellationToken cancellationToken = default)
        {
            SetBusyTimeout(connection);
            return Task.CompletedTask;
        }

        private static void SetBusyTimeout(DbConnection connection)
        {
            using var command = connection.CreateCommand();

            command.CommandText = BusyTimeoutSql;
            command.ExecuteNonQuery();
        }
    }
}