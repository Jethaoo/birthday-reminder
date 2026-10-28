-- Account-level profile fields. The birthday is intentionally nullable so
-- existing accounts can complete it once through the required setup screen.
ALTER TABLE users ADD COLUMN photo_url TEXT;
ALTER TABLE users ADD COLUMN birthday_month INTEGER CHECK (birthday_month BETWEEN 1 AND 12);
ALTER TABLE users ADD COLUMN birthday_day INTEGER CHECK (birthday_day BETWEEN 1 AND 31);
ALTER TABLE users ADD COLUMN birth_year INTEGER CHECK (birth_year BETWEEN 1900 AND 9999);
