-- Modify "accounts" table
ALTER TABLE "public"."accounts" DROP CONSTRAINT "accounts_account_type_check", ADD CONSTRAINT "accounts_account_type_check" CHECK ((account_type)::text = ANY ((ARRAY['checking'::character varying, 'credit_card'::character varying])::text[])), ADD COLUMN "account_balance" numeric(15,2) NOT NULL;
