# Live stream for Job lifecycle events. Every subscriber gets the shared "jobs"
# stream; a client can also scope to a single job with `{ job_id: 123 }` and get
# that job's events only (e.g. the job detail page).
class JobsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "jobs"
    stream_from "job_#{params[:job_id]}" if params[:job_id].present?
  end
end
