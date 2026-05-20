from models.transaction import Transaction

t = Transaction.get_all_transactions()
print(f'Total transactions: {len(t)}\n')
print('Transaction details:')
for i, tx in enumerate(t, 1):
    dept = tx.department if tx.department else 'EMPTY/NULL'
    print(f'{i}. Type: {tx.type:7s} | Dept: {dept:30s} | Points: {tx.points:3d} | Student: {tx.student_name}')

# Count by department
dept_counts = {}
for tx in t:
    dept = tx.department if tx.department else 'EMPTY/NULL'
    if dept in dept_counts:
        dept_counts[dept] += 1
    else:
        dept_counts[dept] = 1

print('\n\nTransactions by department:')
for dept, count in dept_counts.items():
    print(f'  {dept}: {count}')
