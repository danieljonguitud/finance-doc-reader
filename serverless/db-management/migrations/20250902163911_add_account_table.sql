-- Create "accounts" table
CREATE TABLE "public"."accounts" (
  "id" bigserial NOT NULL,
  "user_id" uuid NOT NULL,
  "account_name" character varying(255) NOT NULL,
  "account_type" character varying(50) NOT NULL,
  "institution" character varying(100) NOT NULL,
  "account_number_hash" character varying(64) NOT NULL,
  "display_digits" character varying(10) NULL,
  "is_liability" boolean NULL DEFAULT false,
  "created_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"),
  CONSTRAINT "unique_user_account_hash" UNIQUE ("user_id", "account_number_hash"),
  CONSTRAINT "accounts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "accounts_account_type_check" CHECK ((account_type)::text = ANY ((ARRAY['checking'::character varying, 'savings'::character varying, 'credit_card'::character varying, 'loan'::character varying, 'investment'::character varying])::text[])),
  CONSTRAINT "valid_display_digits" CHECK (((display_digits)::text ~ '^\*{4}\d{1,6}$'::text) OR (display_digits IS NULL))
);
-- Create index "idx_accounts_created_at" to table: "accounts"
CREATE INDEX "idx_accounts_created_at" ON "public"."accounts" ("created_at");
-- Create index "idx_accounts_hash" to table: "accounts"
CREATE INDEX "idx_accounts_hash" ON "public"."accounts" ("account_number_hash");
-- Create index "idx_accounts_user_id" to table: "accounts"
CREATE INDEX "idx_accounts_user_id" ON "public"."accounts" ("user_id");
-- Create index "idx_accounts_user_institution" to table: "accounts"
CREATE INDEX "idx_accounts_user_institution" ON "public"."accounts" ("user_id", "institution");
-- Create index "idx_accounts_user_liability" to table: "accounts"
CREATE INDEX "idx_accounts_user_liability" ON "public"."accounts" ("user_id", "is_liability");
-- Create index "idx_accounts_user_type" to table: "accounts"
CREATE INDEX "idx_accounts_user_type" ON "public"."accounts" ("user_id", "account_type");
-- Modify "transactions" table
ALTER TABLE "public"."transactions" ADD CONSTRAINT "valid_internal_transfer" CHECK ((internal_transfer_id IS NULL) OR (internal_transfer_id <> id)), DROP COLUMN "bank_name", DROP COLUMN "account_holder", ADD COLUMN "account_id" bigint NOT NULL, ADD COLUMN "internal_transfer_id" bigint NULL, ADD CONSTRAINT "transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."accounts" ("id") ON UPDATE NO ACTION ON DELETE CASCADE, ADD CONSTRAINT "transactions_internal_transfer_id_fkey" FOREIGN KEY ("internal_transfer_id") REFERENCES "public"."transactions" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION;
-- Create index "idx_transactions_account_date" to table: "transactions"
CREATE INDEX "idx_transactions_account_date" ON "public"."transactions" ("account_id", "transaction_date" DESC);
-- Create index "idx_transactions_account_id" to table: "transactions"
CREATE INDEX "idx_transactions_account_id" ON "public"."transactions" ("account_id");
-- Create index "idx_transactions_account_type" to table: "transactions"
CREATE INDEX "idx_transactions_account_type" ON "public"."transactions" ("account_id", "transaction_type");
-- Create index "idx_transactions_internal_transfer" to table: "transactions"
CREATE INDEX "idx_transactions_internal_transfer" ON "public"."transactions" ("internal_transfer_id");
-- Create index "idx_transactions_non_transfer" to table: "transactions"
CREATE INDEX "idx_transactions_non_transfer" ON "public"."transactions" ("user_id", "transaction_type", "transaction_date" DESC) WHERE (internal_transfer_id IS NULL);
-- Create index "idx_transactions_user_account" to table: "transactions"
CREATE INDEX "idx_transactions_user_account" ON "public"."transactions" ("user_id", "account_id");
