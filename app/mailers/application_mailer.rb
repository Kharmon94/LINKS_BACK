class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "info@updates.blackcollar.io")
  layout "mailer"
end
