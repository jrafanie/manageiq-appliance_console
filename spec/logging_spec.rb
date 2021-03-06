describe ManageIQ::ApplianceConsole::Logging do
  subject do
    Class.new do
      include ManageIQ::ApplianceConsole::Logging
    end.new
  end

  before do
    subject.logger = nil
    # ManageIQ::ApplianceConsole::Logging's interactive flag uses a shared module instance variable
    # It probably shouldn't be shared.  Hacky fix is to reset the flag back to true.
    subject.interactive = true
  end

  it "should not have default logger when setting" do
    subject.logger = double(:info => true)
    expect(subject.logger.info).to be_truthy
  end

  it "should use default_logger if not set" do
    expect(subject.logger.level).to eq(Logger::INFO)
  end

  it "should have a logger as the default_logger" do
    expect(subject.logger).to be_kind_of(Logger)
    expect(subject.logger.level).to eq(1)
  end

  context "log_and_feedback" do
    it "should log_and_feedback when successful" do
      expect(subject).to receive(:say).with("Method starting")
      expect(subject).to receive(:say).with("Method complete")
      expect(subject.log_and_feedback("method") do
        55
      end).to eq(55)
    end

    it "should log_and_feedback when failing" do
      expect(subject).to receive(:say).with("Test starting")
      expect(subject).to receive(:say).with(/Test.*error.*Issue/)
      expect(subject).to receive(:press_any_key)

      expect { subject.log_and_feedback("test") { raise "Issue" } }.to raise_error(ManageIQ::ApplianceConsole::MiqSignalError)
    end

    it "should log_and_feedback when non-interactively failing" do
      begin
        subject.interactive = false
        expect(subject).to receive(:say).with("Test starting")
        expect(subject).to receive(:say).with(/Test.*error.*Issue/)
        expect(subject).to_not receive(:press_any_key)

        expect { subject.log_and_feedback("test") { raise "Issue" } }.to raise_error(ManageIQ::ApplianceConsole::MiqSignalError)
      ensure
        subject.interactive = true
      end
    end

    it "should raise ArgumentError with no block_given" do
      expect { subject.log_and_feedback(:some_method) }.to raise_error(ArgumentError)
    end

    context "raising exception:" do
      before do
        @backtrace = [
          "gems/linux_admin-0.4.0/lib/linux_admin/common.rb:40:in `run!'",
          "gems/linux_admin-0.4.0/lib/linux_admin/disk.rb:127:in `create_partition_table'",
          "appliance_console/database_configuration_spec.rb:192:in `block (4 levels) in <top (required)>'"
        ]
      end

      it "CommandResultError" do
        result    = double(:error => "stderr", :output => "stdout", :exit_status => 1)
        message   = "some error"
        exception = AwesomeSpawn::CommandResultError.new(message, result)
        exception.set_backtrace(@backtrace)

        expect(subject.logger).to receive(:info)
        expect(subject.logger).to receive(:error)
          .with("MIQ(#some_method)  Command failed: #{message}. Error: stderr. Output: stdout. At: #{@backtrace.last}")
        expect(subject).to receive(:say).with("Some method starting")
        expect(subject).to receive(:say).with(/Some method.*error.*some error/)
        expect(subject).to receive(:press_any_key)

        expect { subject.log_and_feedback(:some_method) { raise exception } }.to raise_error(ManageIQ::ApplianceConsole::MiqSignalError)
      end

      it "ArgumentError" do
        message   = "some error"
        exception = ArgumentError.new(message)
        exception.set_backtrace(@backtrace)
        debugging = "Error: ArgumentError with message: #{message}"

        expect(subject.logger).to receive(:info)
        expect(subject.logger).to receive(:error)
          .with("MIQ(#some_method)  #{debugging}. Failed at: #{@backtrace.first}")

        expect(subject).to receive(:say).with("Some method starting")
        expect(subject).to receive(:say).with(/Some method.*error.*#{debugging}/)
        expect(subject).to receive(:press_any_key)
        expect { subject.log_and_feedback(:some_method) { raise exception } }.to raise_error(ManageIQ::ApplianceConsole::MiqSignalError)
      end
    end
  end
end
