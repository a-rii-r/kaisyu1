public without sharing class CL_ContractCopy {
    //====================
    // 定数
    //====================

    //====================
    // 変数
    //====================

    //====================
    // コンストラクタ
    //  IN
    //    なし
    //  RETURN
    //    なし
    //====================
    public CL_ContractCopy(){

    }

    //====================
    // 初期処理
    //  IN
    //    recordId:対象レコードId
    //    actionType:アクションタイプ(1:更新先含めコピー,2:類似コピー)
    //  RETURN
    //    DTO
    //====================
    @AuraEnabled
    public static CL_ContractCopyDTO init(String recordId, String actionType){
        CL_ContractCopyDTO rtn_dto = new CL_ContractCopyDTO();

        try{
            //--------------------
            // 初期化
            //--------------------
            rtn_dto.recordId = recordId;
            rtn_dto.actionType = actionType;

            //--------------------
            // 契約コピーチェック
            //--------------------
            String errMsg_ContractCopyCheck = contractCopyCheck(rtn_dto);

            if(String.isNotBlank(errMsg_ContractCopyCheck)){
                AuraHandledException auraEx = new AuraHandledException(errMsg_ContractCopyCheck);
                auraEx.setMessage(errMsg_ContractCopyCheck);
                throw auraEx;
            }

            //--------------------
            // 契約コピー処理
            //--------------------
            String errMsg_ContractCopy = contractCopy(rtn_dto);

            if(String.isNotBlank(errMsg_ContractCopy)){
                AuraHandledException auraEx = new AuraHandledException(errMsg_ContractCopy);
                auraEx.setMessage(errMsg_ContractCopy);
                throw auraEx;
            }
        }
        catch(AuraHandledException auraEx){
            throw auraEx;
        }
        catch(Exception ex){
            String errMsg = ex.getMessage();

            AuraHandledException auraEx = new AuraHandledException(errMsg);
            auraEx.setMessage(errMsg);
            throw auraEx;
        }

        return rtn_dto;
    }



    //====================
    // 契約コピーチェック処理
    //  IN
    //    dto:DTO
    //  RETURN
    //    エラーメッセージ
    //====================
    private static String contractCopyCheck(CL_ContractCopyDTO dto){
        String errMsg = '';

        if(dto.actionType == '1'){
            //--------------------
            // 契約取得
            //--------------------
            Contract__c contract = [
                SELECT
                    Id,
                    ToContract__c
                FROM
                    Contract__c
                WHERE
                    Id = :dto.recordId
                LIMIT 1
            ];

            // 更新先コピー済の場合
            if(String.isNotBlank(contract.ToContract__c)){
                errMsg = Label.CDL208_MSG_0002;
            }
        }

        return errMsg;
    }

    //====================
    // 契約コピー処理
    //  IN
    //    dto:DTO
    //  RETURN
    //    エラーメッセージ
    //====================
    private static String contractCopy(CL_ContractCopyDTO dto){
        String errMsg = '';

        Savepoint sp = Database.setSavepoint();

        try{
            if(dto.actionType == '1'){
                //--------------------
                // 契約取得
                //--------------------
                Contract__c originalContract = [
                    SELECT
                        Id,
                        ContractName__c,
                        ContractType__c,
                        WorkType__c,
                        Eigyosho__c,
                        Eigyosho3__c,
                        EigyoTanto__c,
                        EigyoTanto2__c,
                        EstimateType_Judge__c,
                        SekkeiBusho__c,
                        SekkeiBusho2__c,
                        SekkeiTanto__c,
                        Juchusaki__c,
                        Juyosaki__c,
                        Shiharainin__c,
                        SagyoStartDate__c,
                        SagyoEndDate__c,
                        WorkStartDate__c,
                        WorkEndDate__c,
                        ProductName__c,
                        ProductSerialNo__c,
                        MakerHoshuStopYoteibi__c,
                        UpdateDelayPenalty__c,
                        CancelReason__c,
                        CancelReasonDetail__c,
                        LetsEDI_Fukusu__c,
                        HitachiEDI__c,
                        SheetType__c,
                        AccountPassword__c,
                        MonthlyFlag__c,
                        TermQuoteFlag__c,
                        SalesCompanyFlag__c,
                        ContinueFlag__c,
                        EigyoDIFlag__c,
                        AdvancePaymentFlag__c,
                        AccountOther__c,
                        QuoteAddress__c,
                        QuoteSendMethod__c,
                        QuoteSendOther__c,
                        PaymentTerm__c,
                        QuoteOther__c,
                        QuoteRequest1AccountName__c,
                        QuoteRequest1BushoName__c,
                        QuoteRequest1PostalCode__c,
                        QuoteRequest1State__c,
                        QuoteRequest1City__c,
                        QuoteRequest1Street__c,
                        QuoteRequest1Phone__c,
                        QuoteRequest1Mail__c,
                        QuoteRequest1ContactLastName__c,
                        QuoteRequest1ContactFirstName__c,
                        QuoteRequest2AccountName__c,
                        QuoteRequest2BushoName__c,
                        QuoteRequest2PostalCode__c,
                        QuoteRequest2State__c,
                        QuoteRequest2City__c,
                        QuoteRequest2Street__c,
                        QuoteRequest2Phone__c,
                        QuoteRequest2Mail__c,
                        QuoteRequest2ContactLastName__c,
                        QuoteRequest2ContactFirstName__c,
                        QuoteRequest3AccountName__c,
                        QuoteRequest3BushoName__c,
                        QuoteRequest3PostalCode__c,
                        QuoteRequest3State__c,
                        QuoteRequest3City__c,
                        QuoteRequest3Street__c,
                        QuoteRequest3Phone__c,
                        QuoteRequest3Mail__c,
                        QuoteRequest3ContactLastName__c,
                        QuoteRequest3ContactFirstName__c,
                        QuoteAddress1AccountName__c,
                        QuoteAddress1BushoName__c,
                        QuoteAddress1PostalCode__c,
                        QuoteAddress1State__c,
                        QuoteAddress1City__c,
                        QuoteAddress1Street__c,
                        QuoteAddress1Phone__c,
                        QuoteAddress1Mail__c,
                        QuoteAddress1ContactLastName__c,
                        QuoteAddress1ContactFirstName__c,
                        QuoteAddress2AccountName__c,
                        QuoteAddress2BushoName__c,
                        QuoteAddress2PostalCode__c,
                        QuoteAddress2State__c,
                        QuoteAddress2City__c,
                        QuoteAddress2Street__c,
                        QuoteAddress2Phone__c,
                        QuoteAddress2Mail__c,
                        QuoteAddress2ContactLastName__c,
                        QuoteAddress2ContactFirstName__c,
                        QuoteAddress3AccountName__c,
                        QuoteAddress3BushoName__c,
                        QuoteAddress3PostalCode__c,
                        QuoteAddress3State__c,
                        QuoteAddress3City__c,
                        QuoteAddress3Street__c,
                        QuoteAddress3Phone__c,
                        QuoteAddress3Mail__c,
                        QuoteAddress3ContactLastName__c,
                        QuoteAddress3ContactFirstName__c,
                        PartitionQuote__c,
                        PartitionQuoteOther__c,
                        PartitionQuoteRequest1AccountName__c,
                        PartitionQuoteRequest1BushoName__c,
                        PartitionQuoteRequest1PostalCode__c,
                        PartitionQuoteRequest1State__c,
                        PartitionQuoteRequest1City__c,
                        PartitionQuoteRequest1Street__c,
                        PartitionQuoteRequest1Phone__c,
                        PartitionQuoteRequest1Mail__c,
                        PartitionQuoteRequest1ContactLastName__c,
                        PartitionQuoteRequest1ContactFirstName__c,
                        PartitionQuoteRequest2AccountName__c,
                        PartitionQuoteRequest2BushoName__c,
                        PartitionQuoteRequest2PostalCode__c,
                        PartitionQuoteRequest2State__c,
                        PartitionQuoteRequest2City__c,
                        PartitionQuoteRequest2Street__c,
                        PartitionQuoteRequest2Phone__c,
                        PartitionQuoteRequest2Mail__c,
                        PartitionQuoteRequest2ContactLastName__c,
                        PartitionQuoteRequest2ContactFirstName__c,
                        PartitionQuoteRequest3AccountName__c,
                        PartitionQuoteRequest3BushoName__c,
                        PartitionQuoteRequest3PostalCode__c,
                        PartitionQuoteRequest3State__c,
                        PartitionQuoteRequest3City__c,
                        PartitionQuoteRequest3Street__c,
                        PartitionQuoteRequest3Phone__c,
                        PartitionQuoteRequest3Mail__c,
                        PartitionQuoteRequest3ContactLastName__c,
                        PartitionQuoteRequest3ContactFirstName__c,
                        ArrangeOther__c,
                        IsAutoExtensionClause__c,
                        IsOrderConfirm__c,
                        OrderConfirmSendOther__c,
                        IsStamp__c,
                        StampAmount__c,
                        OrderConfirmAddress__c,
                        OrderConfirmSendMethod__c,
                        OrderOther__c,
                        JuchusakiAccount1AccountName__c,
                        JuchusakiAccount1BushoName__c,
                        JuchusakiAccount1PostalCode__c,
                        JuchusakiAccount1State__c,
                        JuchusakiAccount1City__c,
                        JuchusakiAccount1Street__c,
                        JuchusakiAccount1Phone__c,
                        JuchusakiAccount1Mail__c,
                        JuchusakiAccount1ContactLastName__c,
                        JuchusakiAccount1ContactFirstName__c,
                        JuchusakiAccount2AccountName__c,
                        JuchusakiAccount2BushoName__c,
                        JuchusakiAccount2PostalCode__c,
                        JuchusakiAccount2State__c,
                        JuchusakiAccount2City__c,
                        JuchusakiAccount2Street__c,
                        JuchusakiAccount2Phone__c,
                        JuchusakiAccount2Mail__c,
                        JuchusakiAccount2ContactLastName__c,
                        JuchusakiAccount2ContactFirstName__c,
                        JuchusakiAccount3AccountName__c,
                        JuchusakiAccount3BushoName__c,
                        JuchusakiAccount3PostalCode__c,
                        JuchusakiAccount3State__c,
                        JuchusakiAccount3City__c,
                        JuchusakiAccount3Street__c,
                        JuchusakiAccount3Phone__c,
                        JuchusakiAccount3Mail__c,
                        JuchusakiAccount3ContactLastName__c,
                        JuchusakiAccount3ContactFirstName__c,
                        OrderConfirmAddress1AccountName__c,
                        OrderConfirmAddress1BushoName__c,
                        OrderConfirmAddress1PostalCode__c,
                        OrderConfirmAddress1State__c,
                        OrderConfirmAddress1City__c,
                        OrderConfirmAddress1Street__c,
                        OrderConfirmAddress1Phone__c,
                        OrderConfirmAddress1Mail__c,
                        OrderConfirmAddress1ContactLastName__c,
                        OrderConfirmAddress1ContactFirstName__c,
                        OrderConfirmAddress2AccountName__c,
                        OrderConfirmAddress2BushoName__c,
                        OrderConfirmAddress2PostalCode__c,
                        OrderConfirmAddress2State__c,
                        OrderConfirmAddress2City__c,
                        OrderConfirmAddress2Street__c,
                        OrderConfirmAddress2Phone__c,
                        OrderConfirmAddress2Mail__c,
                        OrderConfirmAddress2ContactLastName__c,
                        OrderConfirmAddress2ContactFirstName__c,
                        OrderConfirmAddress3AccountName__c,
                        OrderConfirmAddress3BushoName__c,
                        OrderConfirmAddress3PostalCode__c,
                        OrderConfirmAddress3State__c,
                        OrderConfirmAddress3City__c,
                        OrderConfirmAddress3Street__c,
                        OrderConfirmAddress3Phone__c,
                        OrderConfirmAddress3Mail__c,
                        OrderConfirmAddress3ContactLastName__c,
                        OrderConfirmAddress3ContactFirstName__c,
                        DeliverySlipSendMethod__c,
                        DeliverySlipSendOther__c,
                        DeliveryInspectionOther__c,
                        DeliverySlipAddress1AccountName__c,
                        DeliverySlipAddress1BushoName__c,
                        DeliverySlipAddress1PostalCode__c,
                        DeliverySlipAddress1State__c,
                        DeliverySlipAddress1City__c,
                        DeliverySlipAddress1Street__c,
                        DeliverySlipAddress1Phone__c,
                        DeliverySlipAddress1Mail__c,
                        DeliverySlipAddress1ContactLastName__c,
                        DeliverySlipAddress1ContactFirstName__c,
                        DeliverySlipAddress2AccountName__c,
                        DeliverySlipAddress2BushoName__c,
                        DeliverySlipAddress2PostalCode__c,
                        DeliverySlipAddress2State__c,
                        DeliverySlipAddress2City__c,
                        DeliverySlipAddress2Street__c,
                        DeliverySlipAddress2Phone__c,
                        DeliverySlipAddress2Mail__c,
                        DeliverySlipAddress2ContactLastName__c,
                        DeliverySlipAddress2ContactFirstName__c,
                        DeliverySlipAddress3AccountName__c,
                        DeliverySlipAddress3BushoName__c,
                        DeliverySlipAddress3PostalCode__c,
                        DeliverySlipAddress3State__c,
                        DeliverySlipAddress3City__c,
                        DeliverySlipAddress3Street__c,
                        DeliverySlipAddress3Phone__c,
                        DeliverySlipAddress3Mail__c,
                        DeliverySlipAddress3ContactLastName__c,
                        DeliverySlipAddress3ContactFirstName__c,
                        IsBillingConfirm__c,
                        BillingSendOther__c,
                        BillingSendMethod__c,
                        BillingOther__c,
                        BillingAddress1AccountName__c,
                        BillingAddress1BushoName__c,
                        BillingAddress1PostalCode__c,
                        BillingAddress1State__c,
                        BillingAddress1City__c,
                        BillingAddress1Street__c,
                        BillingAddress1Phone__c,
                        BillingAddress1Mail__c,
                        BillingAddress1ContactLastName__c,
                        BillingAddress1ContactFirstName__c,
                        BillingAddress2AccountName__c,
                        BillingAddress2BushoName__c,
                        BillingAddress2PostalCode__c,
                        BillingAddress2State__c,
                        BillingAddress2City__c,
                        BillingAddress2Street__c,
                        BillingAddress2Phone__c,
                        BillingAddress2Mail__c,
                        BillingAddress2ContactLastName__c,
                        BillingAddress2ContactFirstName__c,
                        BillingAddress3AccountName__c,
                        BillingAddress3BushoName__c,
                        BillingAddress3PostalCode__c,
                        BillingAddress3State__c,
                        BillingAddress3City__c,
                        BillingAddress3Street__c,
                        BillingAddress3Phone__c,
                        BillingAddress3Mail__c,
                        BillingAddress3ContactLastName__c,
                        BillingAddress3ContactFirstName__c,
                        BillingOutputPattern__c,
                        BillingReplyEnvelope__c,
                        BillingPDFSend__c
                    FROM
                        Contract__c
                    WHERE
                        Id = :dto.recordId
                    LIMIT 1
                ];

                //--------------------
                // 契約コピー
                //--------------------
                Contract__c copyContract = originalContract.clone(false, true, false, false);

                // 作業開始日/作業終了日
                Date nextSagyoStartDate = null;
                if(originalContract.SagyoEndDate__c != null){
                    nextSagyoStartDate = (originalContract.SagyoEndDate__c).addDays(1);
                }

                Date nextSagyoEndDate = null;
                if(originalContract.SagyoStartDate__c != null && originalContract.SagyoEndDate__c != null){
                    Integer tempBetween = (originalContract.SagyoEndDate__c).monthsBetween(nextSagyoStartDate);
                    Integer monthBetween = (originalContract.SagyoStartDate__c).monthsBetween(originalContract.SagyoEndDate__c);
                    
                    if(tempBetween != 0){
                        monthBetween++;
                    }

                    nextSagyoEndDate = (nextSagyoStartDate.addMonths(monthBetween)).addDays(-1);
                }

                copyContract.SagyoStartDate__c = nextSagyoStartDate;
                copyContract.SagyoEndDate__c = nextSagyoEndDate;

                // サービス開始日/サービス終了日
                Date nextWorkStartDate = null;
                if(originalContract.WorkEndDate__c != null){
                    nextWorkStartDate = (originalContract.WorkEndDate__c).addDays(1);
                }

                Date nextWorkEndDate = null;
                if(originalContract.WorkStartDate__c != null && originalContract.WorkEndDate__c != null){
                    Integer tempBetween = (originalContract.WorkEndDate__c).monthsBetween(nextWorkStartDate);
                    Integer monthBetween = (originalContract.WorkStartDate__c).monthsBetween(originalContract.WorkEndDate__c);
                    
                    if(tempBetween != 0){
                        monthBetween++;
                    }

                    nextWorkEndDate = (nextWorkStartDate.addMonths(monthBetween)).addDays(-1);
                }

                copyContract.WorkStartDate__c = nextWorkStartDate;
                copyContract.WorkEndDate__c = nextWorkEndDate;

                // 更新元
                copyContract.FromContract__c = originalContract.Id;

                Database.insert(copyContract);

                //--------------------
                // 更新先設定
                //--------------------
                Contract__c updateContract = new Contract__c(
                    Id = originalContract.Id,
                    ToContract__c = copyContract.Id
                );

                Database.update(updateContract);

                //--------------------
                // 契約関係者取得
                //--------------------
                List<ContractMember__c> originalContractMemberList = [
                    SELECT
                        Id,
                        Contract__c,
                        ContractMemberMaster__c,
                        ContractMemberType__c,
                        PartitionQuoteRequestFlag__c
                    FROM
                        ContractMember__c
                    WHERE
                        Contract__c = :dto.recordId
                ];

                if(!originalContractMemberList.isEmpty()){
                    //--------------------
                    // 契約関係者コピー
                    //--------------------
                    List<ContractMember__c> copyContractMemberList = new List<ContractMember__c>();

                    for(ContractMember__c originalContractMember : originalContractMemberList){
                        ContractMember__c copyContractMember = originalContractMember.clone(false, true, false, false);

                        // 契約
                        copyContractMember.Contract__c = copyContract.Id;

                        copyContractMemberList.add(copyContractMember);
                    }

                    Database.insert(copyContractMemberList);
                }

                //--------------------
                // 変数設定
                //--------------------
                dto.copyContractId = copyContract.Id;
            }
            // 類似コピーの場合
            else if(dto.actionType == '2'){
                //--------------------
                // 契約取得
                //--------------------
                Contract__c originalContract = [
                    SELECT
                        Id,
                        EigyoDIFlag__c,
                        Juchusaki__c,
                        Juyosaki__c,
                        ProductName__c,
                        HitachiEDI__c,
                        AccountPassword__c,
                        SheetType__c,
                        SalesCompanyFlag__c,
                        AdvancePaymentFlag__c
                        //,AccountOther__c
                    FROM
                        Contract__c
                    WHERE
                        Id = :dto.recordId
                    LIMIT 1
                ];

                //--------------------
                // 契約コピー
                //--------------------
                Contract__c copyContract = originalContract.clone(false, true, false, false);

                Database.insert(copyContract);

                //--------------------
                // 変数設定
                //--------------------
                dto.copyContractId = copyContract.Id;
            }
            // 新規作成の場合
            else if(dto.actionType == '3'){
                //--------------------
                // 契約取得
                //--------------------
                Contract__c originalContract = [
                    SELECT
                        Id,
                        EigyoDIFlag__c
                    FROM
                        Contract__c
                    WHERE
                        Id = :dto.recordId
                    LIMIT 1
                ];

                //--------------------
                // 契約コピー
                //--------------------
                Contract__c copyContract = originalContract.clone(false, true, false, false);

                Database.insert(copyContract);

                //--------------------
                // 変数設定
                //--------------------
                dto.copyContractId = copyContract.Id;
            }
        }
        catch(DmlException dmlex){
            Database.rollback(sp);

            errMsg = dmlex.getMessage();
        }
        catch(Exception ex){
            Database.rollback(sp);

            errMsg = ex.getMessage();
        }

        return errMsg;
    }
}