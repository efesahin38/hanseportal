-- Fix foreign key constraints for customer contacts on the orders table
ALTER TABLE "public"."orders" DROP CONSTRAINT "orders_customer_contact_id_fkey";
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_customer_contact_id_fkey" FOREIGN KEY (customer_contact_id) REFERENCES customer_contacts(id) ON DELETE SET NULL;

ALTER TABLE "public"."orders" DROP CONSTRAINT "orders_sachbearbeiter_contact_id_fkey";
ALTER TABLE "public"."orders" ADD CONSTRAINT "orders_sachbearbeiter_contact_id_fkey" FOREIGN KEY (sachbearbeiter_contact_id) REFERENCES customer_contacts(id) ON DELETE SET NULL;

-- Fix RLS policy for operation_plan_personnel so assigned workers can actually see their own assignments!
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."operation_plan_personnel";
CREATE POLICY "Enable read access for everyone in the company" ON "public"."operation_plan_personnel" FOR SELECT USING (true);
