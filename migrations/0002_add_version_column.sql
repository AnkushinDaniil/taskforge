-- Migration 0002: add version column for optimistic locking
ALTER TABLE tasks ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
