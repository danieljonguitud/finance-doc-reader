-- Create "users" table
CREATE TABLE "public"."users" (
  "id" serial NOT NULL,
  "email" character varying(255) NOT NULL,
  "first_name" character varying(100) NOT NULL,
  "last_name" character varying(100) NOT NULL,
  "cognito_sub" uuid NOT NULL,
  "created_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"),
  CONSTRAINT "users_cognito_sub_key" UNIQUE ("cognito_sub"),
  CONSTRAINT "users_email_key" UNIQUE ("email"),
  CONSTRAINT "valid_email" CHECK ((email)::text ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)
);
-- Create index "idx_users_cognito_sub" to table: "users"
CREATE INDEX "idx_users_cognito_sub" ON "public"."users" ("cognito_sub");
-- Create index "idx_users_created_at" to table: "users"
CREATE INDEX "idx_users_created_at" ON "public"."users" ("created_at");
-- Create index "idx_users_email" to table: "users"
CREATE INDEX "idx_users_email" ON "public"."users" ("email");
-- Create "transactions" table
CREATE TABLE "public"."transactions" (
  "id" bigserial NOT NULL,
  "user_id" serial NOT NULL,
  "transaction_date" date NOT NULL,
  "description" text NOT NULL,
  "amount" numeric(15,2) NOT NULL,
  "transaction_type" character varying(20) NOT NULL,
  "category" character varying(100) NOT NULL,
  "bank_name" character varying(100) NULL,
  "account_holder" character varying(255) NULL,
  "created_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("id"),
  CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "transactions_transaction_type_check" CHECK ((transaction_type)::text = ANY ((ARRAY['income'::character varying, 'expense'::character varying])::text[])),
  CONSTRAINT "valid_amount" CHECK (amount <> (0)::numeric)
);
-- Create index "idx_transactions_amount" to table: "transactions"
CREATE INDEX "idx_transactions_amount" ON "public"."transactions" ("amount");
-- Create index "idx_transactions_category" to table: "transactions"
CREATE INDEX "idx_transactions_category" ON "public"."transactions" ("category");
-- Create index "idx_transactions_created_at" to table: "transactions"
CREATE INDEX "idx_transactions_created_at" ON "public"."transactions" ("created_at");
-- Create index "idx_transactions_date" to table: "transactions"
CREATE INDEX "idx_transactions_date" ON "public"."transactions" ("transaction_date");
-- Create index "idx_transactions_type" to table: "transactions"
CREATE INDEX "idx_transactions_type" ON "public"."transactions" ("transaction_type");
-- Create index "idx_transactions_user_category" to table: "transactions"
CREATE INDEX "idx_transactions_user_category" ON "public"."transactions" ("user_id", "category");
-- Create index "idx_transactions_user_date" to table: "transactions"
CREATE INDEX "idx_transactions_user_date" ON "public"."transactions" ("user_id", "transaction_date" DESC);
-- Create index "idx_transactions_user_id" to table: "transactions"
CREATE INDEX "idx_transactions_user_id" ON "public"."transactions" ("user_id");
-- Create index "idx_transactions_user_type_date" to table: "transactions"
CREATE INDEX "idx_transactions_user_type_date" ON "public"."transactions" ("user_id", "transaction_type", "transaction_date" DESC);
