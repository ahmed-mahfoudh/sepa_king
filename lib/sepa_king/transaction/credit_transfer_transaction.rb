# encoding: utf-8
module SEPA
  class CreditTransferTransaction < Transaction
    attr_accessor :service_level

    validates_inclusion_of :service_level, :in => %w(SEPA URGP)

    validate { |t| t.validate_requested_date_after(Date.today) }

    def initialize(attributes = {})
      super
      self.service_level ||= 'SEPA'
    end

    def schema_compatible?(schema_name)
      case schema_name
      when PAIN_001_001_09, PAIN_001_001_09_CH_03, PAIN_001_001_03_CH_02, PAIN_001_002_03
        self.bic.present? && self.service_level == 'SEPA'
      when PAIN_001_003_03
        true
      end
    end
  end
end
