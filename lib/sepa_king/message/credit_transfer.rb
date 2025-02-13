# encoding: utf-8

module SEPA
  class CreditTransfer < Message
    self.account_class = DebtorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = 'CstmrCdtTrfInitn'
    self.known_schemas = [ PAIN_001_003_03, PAIN_001_002_03, PAIN_001_001_09, PAIN_001_001_09_CH_03, PAIN_001_001_03_CH_02 ]

  private
    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        batch_booking:  transaction.batch_booking,
        service_level:  transaction.service_level
      }
    end

    def build_payment_informations(builder, schema_name)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        # All transactions with the same requested_date are placed into the same PmtInf block
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('TRF')
          builder.BtchBookg(group[:batch_booking])
          builder.NbOfTxs(transactions.length)
          builder.CtrlSum('%.2f' % amount_total(transactions))
          builder.PmtTpInf do
            unless [PAIN_001_001_09_CH_03, PAIN_001_001_03_CH_02].include?(schema_name) && group[:service_level] == 'SEPA'
              builder.SvcLvl do
                builder.Cd(group[:service_level])
              end
            end
          end
          if [PAIN_001_001_09, PAIN_001_001_09_CH_03].include?(schema_name)
            builder.ReqdExctnDt do
              builder.Dt(group[:requested_date].iso8601)
            end
          else
            builder.ReqdExctnDt(group[:requested_date].iso8601)
          end
          builder.Dbtr do
            builder.Nm(account.name)
          end
          builder.DbtrAcct do
            builder.Id do
              builder.IBAN(account.iban)
            end
          end
          builder.DbtrAgt do
            builder.FinInstnId do
              if account.bic
                builder.__send__([PAIN_001_001_09, PAIN_001_001_09_CH_03].include?(schema_name) ? 'BICFI' : 'BIC', account.bic)
              else
                builder.Othr do
                  builder.Id('NOTPROVIDED')
                end
              end
            end
          end
          builder.ChrgBr('SLEV')

          transactions.each do |transaction|
            build_transaction(builder, transaction, schema_name)
          end
        end
      end
    end

    def build_transaction(builder, transaction, schema_name)
      builder.CdtTrfTxInf do
        builder.PmtId do
          if transaction.instruction.present?
            builder.InstrId(transaction.instruction)
          end
          builder.EndToEndId(transaction.reference)
        end
        builder.Amt do
          if [PAIN_001_001_09_CH_03, PAIN_001_001_03_CH_02].include?(schema_name)
            builder.InstdAmt('%.2f' % transaction.amount, Ccy: 'CHF')
          else
            builder.InstdAmt('%.2f' % transaction.amount, Ccy: 'EUR')
          end
        end
        if transaction.bic
          builder.CdtrAgt do
            builder.FinInstnId do
              builder.__send__([PAIN_001_001_09, PAIN_001_001_09_CH_03].include?(schema_name) ? 'BICFI' : 'BIC', transaction.bic)
            end
          end
        end
        builder.Cdtr do
          builder.Nm(transaction.name)
        end
        builder.CdtrAcct do
          builder.Id do
            builder.IBAN(transaction.iban)
          end
        end
        if transaction.remittance_information
          builder.RmtInf do
            builder.Ustrd(transaction.remittance_information)
          end
        end
      end
    end
  end
end
