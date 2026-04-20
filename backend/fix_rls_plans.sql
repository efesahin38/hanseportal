DROP POLICY IF EXISTS "Enable read access for everyone in the company" ON "public"."operation_plans";
CREATE POLICY "Enable read access for everyone in the company" ON "public"."operation_plans" FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable read access for everyone in the company" ON "public"."operation_plan_personnel";
CREATE POLICY "Enable read access for everyone in the company" ON "public"."operation_plan_personnel" FOR SELECT USING (true);
