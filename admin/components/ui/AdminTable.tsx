type Column = { key: string; label: string };

function cellText(value: unknown): string {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "نعم" : "لا";
  if (typeof value === "string" || typeof value === "number") return String(value);
  return JSON.stringify(value) ?? String(value);
}

export function AdminTable({ columns, rows, empty = "لا توجد بيانات." }: {
  columns: readonly Column[];
  rows: readonly Record<string, unknown>[];
  empty?: string;
}) {
  if (rows.length === 0) return <div className="emptyState">{empty}</div>;
  return <div className="adminTableWrap"><table className="adminTable">
    <thead><tr>{columns.map((column) => <th key={column.key}>{column.label}</th>)}</tr></thead>
    <tbody>{rows.map((row, index) => <tr key={String(row.id ?? index)}>
      {columns.map((column) => <td key={column.key}>{cellText(row[column.key])}</td>)}
    </tr>)}</tbody>
  </table></div>;
}
