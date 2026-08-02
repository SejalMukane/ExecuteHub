require "rails_helper"

RSpec.describe TestRunProgressUpdater, type: :service do
  describe ".call" do
    context "with all jobs completed" do
      it "marks the run completed and sets 100% progress" do
        test_run = create(:test_run)
        create_list(:job, 4, test_run: test_run, status: :completed)

        expect { described_class.call(test_run) }
          .to change { test_run.reload.status }.from("queued").to("completed")

        expect(test_run.completed_jobs).to eq(4)
        expect(test_run.queued_jobs).to eq(0)
        expect(test_run.failed_jobs).to eq(0)
        expect(test_run.total_jobs).to eq(4)
        expect(test_run.progress_percentage).to eq(100.0)
        expect(test_run.finished_at).to be_present
      end
    end

    context "with a mix of queued and completed jobs" do
      it "computes a partial progress percentage" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed)
        create(:job, test_run: test_run, status: :queued)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.completed_jobs).to eq(1)
        expect(test_run.queued_jobs).to eq(1)
        expect(test_run.progress_percentage).to eq(50.0)
        # A run with in-flight work is "running" even if some jobs are still queued.
        expect(test_run.status).to eq("running")
      end
    end

    context "with at least one running job" do
      it "moves the run from queued to running" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :running)

        described_class.call(test_run)

        expect(test_run.reload.status).to eq("running")
      end

      it "persists the live running bucket (running + uploading_artifacts)" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :running)
        create(:job, test_run: test_run, status: :uploading_artifacts)
        create(:job, test_run: test_run, status: :queued)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.running_jobs).to eq(2)
        expect(test_run.queued_jobs).to eq(1)
        expect(test_run.total_jobs).to eq(3)
      end
    end

    context "with a retrying job" do
      it "counts it as queued (waiting) not running" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :retrying)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.queued_jobs).to eq(1)
        expect(test_run.running_jobs).to eq(0)
      end
    end

    context "with jobs still uploading artifacts" do
      it "keeps the run active instead of completing it" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :uploading_artifacts)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.status).to eq("running")
        expect(test_run.finished_at).to be_nil
      end
    end

    context "with failed jobs and no active jobs" do
      it "marks the run failed" do
        test_run = create(:test_run)
        create(:job, test_run: test_run, status: :completed)
        create(:job, test_run: test_run, status: :failed)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.status).to eq("failed")
        expect(test_run.failed_jobs).to eq(1)
        expect(test_run.progress_percentage).to eq(50.0)
      end
    end

    context "with no jobs" do
      it "reports zero progress and stays queued" do
        test_run = create(:test_run)

        described_class.call(test_run)

        test_run.reload
        expect(test_run.progress_percentage).to eq(0.0)
        expect(test_run.completed_jobs).to eq(0)
        expect(test_run.status).to eq("queued")
      end
    end
  end
end
