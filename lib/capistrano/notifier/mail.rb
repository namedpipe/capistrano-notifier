require 'capistrano/notifier'

begin
  require 'action_mailer'
rescue LoadError => e
  require 'actionmailer'
end

class Capistrano::Notifier::Mailer < ActionMailer::Base

  if ActionMailer::Base.respond_to?(:mail)
    def notice(text, from, subject, to, delivery_method)
      mail({
        :body => text,
        :delivery_method => delivery_method,
        :from => from,
        :subject => subject,
        :to => to
      })
    end
  else
    def notice(text, from, subject, to)
      body text
      from from
      subject subject
      recipients to
      content_type "text/html"
    end
  end

end

class Capistrano::Notifier::Mail < Capistrano::Notifier::Base
  def self.load_into(configuration)
    configuration.load do
      namespace :deploy do
        namespace :notify do
          desc 'Send a deployment notification via email.'
          task :mail do
            Capistrano::Notifier::Mail.new(configuration).perform

            if configuration.notifier_mail_options[:method] == :test
              puts ActionMailer::Base.deliveries
            end
          end
        end
      end

      after 'deploy:restart', 'deploy:notify:mail'
    end
  end

  def perform
    if defined?(ActionMailer::Base) && ActionMailer::Base.respond_to?(:mail)
      perform_with_action_mailer
    else
      perform_with_legacy_action_mailer
    end
  end

  private

  def perform_with_legacy_action_mailer(notifier = Capistrano::Notifier::Mailer)
    notifier.delivery_method = notify_method
    notifier.deliver_notice(text, from, subject, to)
  end

  def perform_with_action_mailer(notifier = Capistrano::Notifier::Mailer)
    notifier.smtp_settings = smtp_settings
    notifier.notice(text, from, subject, to, notify_method).deliver
  end

  def body
    <<-BODY.gsub(/^ {6}/, '')
<pre>
DEPLOYER:     #{user_name}
BRANCH:       #{branch}
ENVIRONMENT:  #{stage}
WHEN:         #{now.strftime("%m/%d/%Y")} at #{now.strftime("%I:%M %p %Z")}

#{git_range}

CHANGES
============================

#{git_log}
</pre>
    BODY
  end

  def from
    cap.notifier_mail_options[:from]
  end

  def git_commit_prefix
    "#{git_prefix}/commit"
  end

  def git_compare_prefix
    "#{git_prefix}/compare"
  end

  def git_prefix
    giturl ? giturl : "https://github.com/#{github}"
  end

  def github
    cap.notifier_mail_options[:github]
  end

  def giturl
    cap.notifier_mail_options[:giturl]
  end

  def html
    body.gsub(
      /([0-9a-f]{7})\.\.([0-9a-f]{7})/, "<a href=\"#{git_compare_prefix}/\\1...\\2\">\\1..\\2</a>"
    ).gsub(
      /^([0-9a-f]{7})/, "<a href=\"#{git_commit_prefix}/\\0\">\\0</a>"
    )
  end

  def notify_method
    cap.notifier_mail_options[:method]
  end

  def smtp_settings
    cap.notifier_mail_options[:smtp_settings]
  end

  def subject
    "#{application.titleize} branch #{branch} deployed to #{stage}"
  end

  def text
    body.gsub(/([0-9a-f]{7})\.\.([0-9a-f]{7})/, "#{git_compare_prefix}/\\1...\\2")
  end

  def to
    cap.notifier_mail_options[:to]
  end
end

if Capistrano::Configuration.instance
  Capistrano::Notifier::Mail.load_into(Capistrano::Configuration.instance)
end
