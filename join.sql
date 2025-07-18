FULL OUTER JOIN, which returns all records when there is a match in either left or right table. If there is no match, the result will contain NULL values for the missing side.

🧱 Sample Tables
Table: employees
emp_id	emp_name
1	John
2	Alice
3	Bob

Table: salaries
emp_id	salary
2	50000
3	60000
4	70000

🔄 Query: FULL OUTER JOIN
sql
Copy
Edit
SELECT 
    e.emp_id AS employee_id,
    e.emp_name,
    s.salary
FROM 
    employees e
FULL OUTER JOIN 
    salaries s
ON 
    e.emp_id = s.emp_id;
📊 Output
employee_id	emp_name	salary
1	John	NULL
2	Alice	50000
3	Bob	60000
4	NULL	70000

FULL OUTER JOIN (Valid & Specific)
Returns:
All records from left table
All records from right table
NULLs for non-matching rows

What is a LEFT JOIN?
A LEFT JOIN returns:

All rows from the left table

Matched rows from the right table

If there's no match, it shows NULL for right-side columns.

Table: employees
emp_id	emp_name
1	John
2	Alice
3	Bob

Table: salaries
emp_id	salary
2	50000
3	60000

🔍 SQL LEFT JOIN Query
sql
Copy
Edit
SELECT 
    e.emp_id,
    e.emp_name,
    s.salary
FROM 
    employees e
LEFT JOIN 
    salaries s
ON 
    e.emp_id = s.emp_id;
📊 Output
emp_id	emp_name	salary
1	John	NULL
2	Alice	50000
3	Bob	60000




