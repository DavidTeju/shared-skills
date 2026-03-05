---
name: prisma-migration-drift-recovery
description: |
  Safely handle Prisma migration drift on existing databases without data loss. Use when:
  (1) "prisma migrate dev" shows "Drift detected: Your database schema is not in sync",
  (2) Prisma asks "We need to reset the schema. All data will be lost. Do you want to continue?",
  (3) Database was created via Supabase, direct SQL, or another ORM before adopting Prisma,
  (4) Adding schema changes to a production database that wasn't initialized with Prisma migrations.
  Covers baselining existing databases and applying incremental changes safely.
author: Claude Code
user-invocable: false
---

# Prisma Migration Drift Recovery

## Problem

When running `prisma migrate dev` on a database that wasn't created through Prisma migrations (e.g., Supabase, direct SQL, another ORM), Prisma detects "drift" and offers to **reset the entire database**, which would delete all data.

## Context / Trigger Conditions

You'll see output like this:

```
Drift detected: Your database schema is not in sync with your migration history.

[+] Added tables
  - users
  - posts
  ...

? We need to reset the "public" schema at "your-database:5432"
Do you want to continue? All data will be lost. › (y/N)
```

This happens when:
- Database was created via Supabase dashboard or migrations
- Database was set up with raw SQL scripts
- Database was managed by another ORM (TypeORM, Sequelize, etc.)
- You're adopting Prisma on an existing project
- Migration history is out of sync (missing migration files, different environments)

## Solution

### Option 1: Apply Changes Directly via SQL (Recommended for Simple Changes)

For simple schema changes like adding an index:

```bash
# 1. Apply the change directly to the database
psql -h your-host -U postgres -d your-db -c "CREATE INDEX IF NOT EXISTS your_index_name ON your_table(column1, column2);"

# Or via Docker:
docker exec -it your-db-container psql -U postgres -d postgres -c "CREATE INDEX IF NOT EXISTS your_index_name ON your_table(column1, column2);"

# 2. Keep your schema.prisma file updated to reflect the change
# (The @@index directive should already be there if you're making this change)

# 3. Verify sync (optional)
npx prisma db pull  # This updates schema.prisma to match database
```

### Option 2: Baseline the Database (For Full Prisma Migration Adoption)

If you want to fully adopt Prisma migrations going forward:

```bash
# 1. Create the migrations directory
mkdir -p prisma/migrations/0_init

# 2. Generate SQL that represents your current schema
npx prisma migrate diff \
  --from-empty \
  --to-schema-datamodel prisma/schema.prisma \
  --script > prisma/migrations/0_init/migration.sql

# 3. Mark this migration as already applied (since the database already has this schema)
npx prisma migrate resolve --applied 0_init

# 4. Now you can safely run new migrations
npx prisma migrate dev --name your_new_change
```

### Option 3: Pull and Regenerate (When Schema File is Out of Sync)

If your `schema.prisma` doesn't match the database:

```bash
# 1. Pull the actual database schema into schema.prisma
npx prisma db pull

# 2. Review the changes
git diff prisma/schema.prisma

# 3. Then follow Option 2 to baseline
```

## Verification

After applying changes:

```bash
# Check the table structure includes your changes
psql -c "\d your_table_name"

# Or via Prisma
npx prisma db pull
npx prisma validate
```

## Example

**Scenario**: Adding a composite index to a `responses` table on a Supabase database.

```bash
# DON'T do this (will delete all data):
# npx prisma migrate dev --name add_responses_index

# DO this instead:
ssh root@your-vps "docker exec supabase-db psql -U postgres -d postgres -c \"CREATE INDEX IF NOT EXISTS responses_collegeid_questionid_idx ON responses(collegeid, questionid);\""

# Verify:
ssh root@your-vps "docker exec supabase-db psql -U postgres -d postgres -c \"\\d responses\""
# Should show the new index in the Indexes section
```

## Notes

- **Never press 'y' on the reset prompt** if you have data you care about
- `prisma migrate dev` is designed for development, not production
- For production deployments, use `prisma migrate deploy` which only applies pending migrations
- Supabase manages its own migrations separately from Prisma
- The `directUrl` in your schema.prisma is for migrations (bypasses connection pooler)
- After direct SQL changes, your `schema.prisma` should still reflect the intended state

## References

- [Prisma: Baselining a Database](https://www.prisma.io/docs/orm/prisma-migrate/workflows/baselining)
- [Prisma: Troubleshooting Development](https://www.prisma.io/docs/guides/database/developing-with-prisma-migrate/troubleshooting-development)
- [Prisma: Add Prisma to Existing Project](https://www.prisma.io/docs/getting-started/setup-prisma/add-to-existing-project)
