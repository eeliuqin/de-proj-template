"""
create bitcoin schema
"""

from typing import Any

from yoyo import step

__depends__: Any = {}

# in yoyo, each step has 2 parts: the first arugment is forward migration, the 2nd is backward migration
steps = [step("CREATE SCHEMA bitcoin", "DROP SCHEMA bitcoin")]

# Ex: you can create multiple steps
# when run `yoyo develop`, it executes all forward migrations by order
# when run `yoyo rollback`, it executes all backward migrations by reverse order

# steps = [
#     step(
#         "CREATE SCHEMA bitcoin",  # Forward migration
#         "DROP SCHEMA bitcoin"  # Backward migration (rollback)
#     ),
#     step(
#         "CREATE TABLE bitcoin.transactions (id SERIAL PRIMARY KEY, amount DECIMAL)",  # Forward migration
#         "DROP TABLE bitcoin.transactions"  # Backward migration (rollback)
#     ),
#     step(
#         "ALTER TABLE bitcoin.transactions ADD COLUMN description TEXT",  # Forward migration
#         "ALTER TABLE bitcoin.transactions DROP COLUMN description"  # Backward migration (rollback)
#     )
# ]
