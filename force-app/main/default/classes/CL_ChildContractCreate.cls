public without sharing class CL_ChildContractCreate {
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
    public CL_ChildContractCreate(){

    }

    //====================
    // 初期処理
    //  IN
    //    recordId:対象レコードId
    //  RETURN
    //    DTO
    //====================
    @AuraEnabled
    public static CL_ChildContractCreateDTO init(String recordId){
        CL_ChildContractCreateDTO rtn_dto = new CL_ChildContractCreateDTO();

        try{
            //--------------------
            // 設定
            //--------------------
            init_Setting(rtn_dto, recordId);
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
    // 作成ボタン処理
    //  IN
    //    dto:DTO
    //  RETURN
    //    DTO
    //====================
    @AuraEnabled
    public static CL_ChildContractCreateDTO btn_Create(CL_ChildContractCreateDTO dto){
        CL_ChildContractCreateDTO rtn_dto = dto;

        try{
            //--------------------
            // 作成
            //--------------------
            String errorMsg_Create_Create = create_Create(dto);
            if(String.isNotBlank(errorMsg_Create_Create)){
                AuraHandledException auraEx = new AuraHandledException(errorMsg_Create_Create);
                auraEx.setMessage(errorMsg_Create_Create);
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
    // 初期処理_設定
    //  IN
    //    dto:DTO
    //  RETURN
    //    なし
    //====================
    private static void init_Setting(CL_ChildContractCreateDTO dto, String recordId){
        //--------------------
        // 設定
        //--------------------
        // 対象レコードId
        dto.recordId = recordId;

        // 選択リスト情報
        // 選択リスト_販売種別
        List<String> salesTypeStrList = new List<String>{
            '売切',
            '定期'
        };

        for(String salesTypeStr : salesTypeStrList){
            dto.picklistInfo.salesTypePicklist.add(new CL_ChildContractCreateDTO.ListOption(salesTypeStr, salesTypeStr));
        }

        // 選択リスト_開始日(年)
        Date currentDate = Date.today();
        Integer currentYear = currentDate.year();
        List<String> yaerStrList = new List<String>{
            String.valueOf(currentYear-2),
            String.valueOf(currentYear-1),
            String.valueOf(currentYear),
            String.valueOf(currentYear+1),
            String.valueOf(currentYear+2),
            String.valueOf(currentYear+3)
        };

        for(String yaerStr : yaerStrList){
            dto.picklistInfo.startYearPicklist.add(new CL_ChildContractCreateDTO.ListOption(yaerStr, yaerStr));
        }

        // 選択リスト_開始日(月)
        for(Integer i=1; i<=12; i++){
            String monthStr = (String.valueOf(i)).leftPad(2, '0');
            dto.picklistInfo.startMonthPicklist.add(new CL_ChildContractCreateDTO.ListOption(monthStr, monthStr));
        }
    }

    //====================
    // 作成ボタン_作成
    //  IN
    //    dto:DTO
    //  RETURN
    //    エラーメッセージ
    //====================
    private static String create_Create(CL_ChildContractCreateDTO dto){
        String errorMsg = '';

        Savepoint sp = Database.setSavepoint();

        try{
            // --------------------
            // 契約取得
            // --------------------
            Contract__c originalContract = [
                SELECT
                    Id,
                    Eigyosho__c,
                    EigyoTanto__c,
                    Shiharainin__c,
                    PaymentTerm__c,
                    ContractName__c,
                    ContractType__c,
                    EigyoshoManualInput__c,
                    EigyoTantoManualInput__c,
                    SekkeiBusho__c,
                    SekkeiTanto__c,
                    Juchusaki__c,
                    Juyosaki__c,
                    ProductName__c,
                    ProductSerialNo__c,
                    MakerHoshuStopYoteibi__c,
                    UpdateStatus__c,
                    UpdateDelayPenalty__c,
                    CancelReason__c,
                    CancelReasonDetail__c,
                    HitachiEDI__c,
                    SheetType__c,
                    AccountPassword__c,
                    EigyoDITanto__c,
                    JimuTanto__c,
                    EigyoDITanto2__c,
                    JimuTanto2__c,
                    MonthlyFlag__c,
                    TermQuoteFlag__c,
                    SalesCompanyFlag__c,
                    ContinueFlag__c,
                    EigyoDIFlag__c,
                    AccountOther__c,
                    QuoteAddress__c,
                    QuoteSendMethod__c,
                    QuoteSendOther__c,
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
                    PartitionQuoteExpirationDate__c,
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

                    //追加
                    SekkeiBusho2__c,
                    Eigyosho3__c,
                    EigyoTanto2__c,
                    BoxLink__c,
                    JimuTantoFlag__c,
                    AdvancePaymentFlag__c

                FROM
                    Contract__c
                WHERE
                    Id = :dto.recordId
                LIMIT 1
            ];

            //--------------------
            // 子契約作成
            //--------------------
            List<Contract__c> childContractList = new List<Contract__c>();

            // 開始日/終了日
            Date startDate = Date.newInstance(Integer.valueOf(dto.inputInfo.startYearStr), Integer.valueOf(dto.inputInfo.startMonthStr), 1);
            Date endDate = (startDate.addMonths(1)).addDays(-1);

            for(Integer i=0; i<dto.inputInfo.createNum; i++){
                Contract__c childContract = originalContract.clone(false, true, false, false);

                // 親契約
                childContract.ParentContract__c = dto.recordId;
                // 子契約フラグ
                childContract.ChildContractFlag__c = true;

                // 開始日/終了日
                if(dto.inputInfo.salesType == '売切'){
                    // 作業開始日
                    childContract.SagyoStartDate__c = startDate;
                    // 作業終了日
                    childContract.SagyoEndDate__c = endDate;
                }
                else if(dto.inputInfo.salesType == '定期'){
                    // サービス開始日
                    childContract.WorkStartDate__c = startDate;
                    // サービス終了日
                    childContract.WorkEndDate__c = endDate;
                }

                startDate = startDate.addMonths(1);
                endDate = (startDate.addMonths(1)).addDays(-1);

                childContractList.add(childContract);
            }

            Database.insert(childContractList);

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

                for(Contract__c childContract : childContractList){
                    for(ContractMember__c originalContractMember : originalContractMemberList){
                        ContractMember__c copyContractMember = originalContractMember.clone(false, true, false, false);

                        // 契約
                        copyContractMember.Contract__c = childContract.Id;

                        copyContractMemberList.add(copyContractMember);
                    }
                }

                Database.insert(copyContractMemberList);
            }
        }
        catch(DmlException dmlex){
            Database.rollback(sp);

            errorMsg = dmlex.getMessage();
        }
        catch(Exception ex){
            Database.rollback(sp);

            errorMsg = ex.getMessage();
        }

        return errorMsg;
    }
}