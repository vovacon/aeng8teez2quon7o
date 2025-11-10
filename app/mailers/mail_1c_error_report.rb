# encoding: utf-8

Rozario::App.mailer :mail_1c_error_report do
  email :error_report do |request_id, timestamp, error_details, log_excerpt|
    from "1C Integration Monitor <no-reply@#{CURRENT_DOMAIN}>"
    to ENV['ADMIN_EMAIL']
    subject "[КРИТИЧНО] Ошибка в 1C интеграции - #{timestamp}"
    locals(
      request_id: request_id,
      timestamp: timestamp, 
      error_details: error_details,
      log_excerpt: log_excerpt,
      server_info: {
        environment: PADRINO_ENV,
        host: CURRENT_DOMAIN,
        ruby_version: RUBY_VERSION
      }
    )
    body render 'mail_1c_error_report/error_report'
    content_type :html
  end
  
  email :success_report do |request_id, timestamp, statistics|
    from "1C Integration Monitor <no-reply@#{CURRENT_DOMAIN}>"
    to ENV['ADMIN_EMAIL']
    subject "[УСПЕХ] 1C интеграция завершена успешно - #{timestamp}"
    locals(
      request_id: request_id,
      timestamp: timestamp,
      statistics: statistics,
      server_info: {
        environment: PADRINO_ENV,
        host: CURRENT_DOMAIN,
        ruby_version: RUBY_VERSION
      }
    )
    body render 'mail_1c_error_report/success_report'
    content_type :html
  end
end
