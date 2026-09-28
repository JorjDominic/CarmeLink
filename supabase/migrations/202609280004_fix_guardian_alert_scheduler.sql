-- Run guardian presence alerts in the selected minute. The original job ran
-- every five minutes, which made a saved cutoff appear not to fire on time.
do $$
declare
  v_job record;
begin
  for v_job in
    select jobid from cron.job where jobname = 'guardian-presence-alerts'
  loop
    perform cron.alter_job(v_job.jobid, schedule := '* * * * *');
  end loop;
end $$;

