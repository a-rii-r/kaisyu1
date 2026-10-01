/**
 * 契約基盤QuickCIS連携共通クラス
 * 以下のバッチで使用する共通処理を実装
 * ・CMN_ContractToQuickCISBatch
 * ・CMN_ContractToQuickCISVsCstmNmBatch
 * ・CMN_ContractToQuickCISChildBatch
 * 
 * 2025-01-31 PSOL 新規作成
 * 2025-11-28 FSI  請求基盤を用いた月分合算対応（ARVE-5846)
 * 2026-01-22 FSI  [請求プロセス改善 ー 支払情報の履歴取得] KT2業務プロセステスト発生課題対応 (ARVE-6724)
 * 2026-01-22 USE  予備電力の契約廃止に対応 (PRICE_REVISION_2025-1344) -> OCP_SFDC_MAINTE-232で対応削除
 * 2026-02-04 USE  異容量判定ロジックの変更に対応 (PRICE_REVISION_2025-1499)
 * 2026-02-04 USE  T7_アンシラリーサービス料金契約容量(kW）の連携に対応(PRICE_REVISION_2025-1570)
 * 2026-02-17 FSI  [請求プロセス改善 ー 支払情報の履歴取得] ST時不具合対応（ARVE-6798）
 */
public without sharing class CMN_ContractToQuickCISCommon {

    // APIリクエストクラス
    CMN_RestAPIRequest APIRequest = new CMN_RestAPIRequest('QuickCIS');

    // 連携モード（Parent or Parent2 or Child）
    public String mode;
    // ソース
    public String source;

    // マッピング置換用マップ
    // Map<マッピング種別, Map<項目名, Map<ARVEの値, QuickCISの値>>>
    @TestVisible
    private Map<String, Map<String, Map<String, String>>> mapValPattern;

    // マッピング用リスト
    // QuickCIS取引先の作成・更新処理_顧客IDリスト
    private List<String> clientIdList = System.Label.CMN_ContractToQuickCIS_ClientId.split(',');

    // テストクラス用：レスポンスパターン
    public String resPattern;

    // 最新の契約連携バッチ開始時刻
    @TestVisible
    private Datetime contractBatchStartTime;
    
    // 連携モード
    private static final String MODE_P = 'Parent';
    private static final String MODE_P2 = 'Parent2';
    private static final String MODE_C = 'Child';
    private static final String MODE_D = 'Division';
    // 連携区分
    public final String LINKAGEKBN_C = 'Create';
    public final String LINKAGEKBN_U = 'Update';
    public final String LINKAGEKBN_D = 'Delete';
    // 連携ステータス
    public final String LINKSTS_ABLE = '連携可能';
    public final String LINKSTS_LINKED = 'CIS連携済み';
    public final String LINKSTS_ERR = '連携エラー';
    // 呼び出し元クラス判定
    public final String CONTRACT_QUICKCISBATCH = '契約QuickCIS連携バッチ(親)';
    public final String CONTRACT_QUICKCIS_VSCSTMNM_BATCH = '契約QuickCIS連携バッチ(見化不一致)';

    // エラーメッセージ
    public final String ERRMSG001 = 'QuickCISへの接続認証に失敗しました。';
    public final String ERRMSG002 = 'QuickCISからのデータ取得に失敗しました。';
    public final String ERRMSG003 = '連携ステータスの更新に失敗しました。';
    public final String LINKERRORDETAIL_DONE = '既に電力契約が作成されております';
    public final String LINKERRORDETAIL_NOQCISID = 'QuickCIS契約番号が設定されていません';
    public final String LINKERRORDETAIL_NONE = '更新対象がありません';
    public final String LINKERRORDETAIL_FAILED = 'の作成・更新に失敗しました';
    public final String LINKERRORDETAIL_DELETE_FAILED = 'の削除に失敗しました';
    public final String LINKERRORDETAIL_NOQCISPARENT = '紐づけ元契約商品に対応する電力契約がありません';
    public final String LINKERRORDETAIL_CSTNUM_NOT_EQUAL_VISUALCSTNUM = 'お客さま番号と見える化まとめコードが一致しなかったためQuickCIS取引先を作成しませんでした';
    public final String LINKERRORDETAIL_SUMINVOICEID = '合算請求IDなし';
    public final String LINKERRORDETAIL_NOQCISACCMSTITEM = '紐づけ先の設定料金アイテム（需要家別）マスタなし';
    public final String LINKERRORDETAIL_NOT_INPUT_QCISACCMSTITEM = '設定料金アイテム（需要家別）情報が入力されていない';
    public final String LINKERRORDETAIL_INPUT_QCISACCMSTITEM = '設定料金アイテム（需要家別）情報が入力されている';
    public final String LINKERRORDETAIL_INVOICEMETHOD = '支払情報（履歴）請求方式なし';
    
    // マッピング共通処理クラス
    CMN_IntegrationBatchMapper mpgCmnClass = new CMN_IntegrationBatchMapper();

    /**
     * コンストラクタ
     * @param mode 連携モード
     * @throws なし
     * @see なし
     */
    public CMN_ContractToQuickCISCommon(String mode) {

        // 連携モード
        this.mode = mode;
        // ソース（Apexクラス名）※エラーリスト作成時に使用
        String source;
        if(this.mode == MODE_P) {
            this.source = 'CMN_ContractToQuickCISBatch';
        }else if(this.mode == MODE_P2){
            this.source = 'CMN_ContractToQuickCISVsCstmNmBatch';
        }else if(this.mode == MODE_C) {
            this.source = 'CMN_ContractToQuickCISChildBatch';
        }else if(this.mode == MODE_D) {
            this.source = 'CMN_ContractToQuickCISDivisionBatch';
        }

        // マッピング置換用マップに初期値を設定
        setMapValPattern();
        // 最新の契約連携バッチ開始時刻を取得
        getContractBatchStartTime();
    }


    /**
     * エラーリストレコード作成
     * @param errMsg エラーメッセージ
     * @param idSet 処理対象レコードIDセット
     * @return EpccErrorList__c エラーリスト
     * @throws なし
     * @see なし
     */
    public EpccErrorList__c createErrorList(String errMsg, Set<Id> idSet) {

        // IDセットからID連携文字列を生成
        String idSetStr;
        if(idSet != null) {
            idSetStr = String.join(idSet, ',');
        }

        // エラーリストを作成して返す
        return new EpccErrorList__c(
            Source__c = this.source,
            OccurrenceDateTime__c = Datetime.now(),
            ErrorDetail__c = errMsg,
            SorceObjectId__c = idSetStr
        );
    }


    /**
     * 契約商品取得クエリを返す
     * @param なし
     * @return 契約商品取得クエリ
     * @throws なし
     * @see なし
     */
    public String setContractItemQuery() {

        // WHERE句に使用する変数の用意
        // 連携区分セット
        // ※変更異動要件の発生に伴い変更系異動は手動連携での応動となるため、現状の対象区分は親子ともに"Create"のみに設定
        // ARVE-5331：変更系異動連携開始に伴い連携処理区分を"Create"、"Update"、"Delete"に拡大
        Set<String> linkageKbnSet = new Set<String>{LINKAGEKBN_C, LINKAGEKBN_U, LINKAGEKBN_D};
        // Set<String> linkageKbnSet = new Set<String>{LINKAGEKBN_C};
        // 商品ID処理対象リスト
        List<String> skuIdSet = System.Label.CMN_ContractToQuickCIS_SKU.split(',');
        if(Test.isRunningTest()) {
            // Apexテスト実行時、テスト用の商品IDを追加
            skuIdSet.add('P0108013UUNIT');
            skuIdSet.add('P0108013WUNIT');
        }
        // 紐づけ元契約商品
        String hasLinkedSource = this.mode != MODE_C ? '= null' : '!= null';

        // 分割元契約商品
        String hasDivisionSource = this.mode != MODE_D ? '= null' : '!= null';

        String query = 'SELECT Id' +
                            ', Name' +                                                     // 契約番号
                            ', CMN_LinkSts__c' +                                           // 連携ステータス
                            ', CMN_LinkageKbn__c' +                                        // 連携処理区分
                            ', CMN_QCISContractId__c' +                                    // QuickCIS契約番号
            // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
                            ', CMN_ReproducedQCISContractId__c' +                          // QuickCIS契約番号（複製後）
            // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End
                            ', CMN_LinkedSourceContractItem__c' +                          // 紐づけ元契約商品
                            ', CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c' +    // 紐づけ元契約商品.QuickCIS契約番号
            // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
                            ', CMN_LinkedSourceContractItem__r.CMN_ReproducedQCISContractId__c' +   // 紐づけ元契約商品.QuickCIS契約番号（複製後）
            // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End
                            ', CMN_LinkedSourceContractItem__r.CMN_StockKeepingUnit__c' +  // 紐づけ元契約商品.商品ID
                            ', CMN_LinkedSourceContractItem__r.CMN_PowerContract__c ' +    // 紐づけ元契約商品.契約電力(kW)            
                            ', CMN_DivisionSource__c' +                                    // 分割元契約商品
                            ', CMN_DivisionSource__r.CMN_QCISContractId__c' +              // 分割元契約商品.QuickCIS契約番号
             // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
                            ', CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c' +    // 分割元契約商品.QuickCIS契約番号（複製後）
             // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End
                            ', CMN_DivisionSource__r.CMN_VisualizationCustomerNum__c' +    // 分割元契約商品.見える化まとめコード
                            ', CMN_DivisionSource__r.CMN_SupplyPointSpecificNum__c' +      // 分割元契約商品.供給地点特定番号
            // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
                            ', CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__c' +                                    // 紐づけ元契約商品.複製契約商品
                            ', CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_QCISContractId__c' +              // 紐づけ元契約商品.複製契約商品.QuickCIS契約番号
                            ', CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c' +    // 紐づけ元契約商品.複製契約商品.QuickCIS契約番号（複製後）
            // 2026/02/16 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End
                            // 2026/02/21 「PRICE_REVISION_2025-1547 追加要件①」 坂寄 Add End
                            ', CMN_DivisionSource__r.CMN_ReproduceContractItem__c' +                        // 分割元契約商品.複製契約商品
                            ', CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_QCISContractId__c' +                        // 分割元契約商品.複製契約商品.QuickCIS契約番号
                            ', CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c' +              // 分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）
                            // 2026/02/21 「PRICE_REVISION_2025-1547 追加要件①」 坂寄 Add End
                            ', CMN_StockKeepingUnit__c' +                                  // 商品ID
                            ', CMN_LinkErrorDetail__c' +                                   // 連携エラー内容
                            ', CMN_NotificationMethod__c' +                                // 通知方法
                            ', CMN_DateDivisionDate__c' +                                  // 日付分割日
                            ', CMN_SupplyPointSpecificNum__c' +                            // 供給地点特定番号
                            ', CMN_OrderItem__c' +                                         // 申込商品番号
                            ', CMN_OrderItem__r.CMN_TypeDetail__c' +                       // 申込商品番号.申込種別詳細
                            ', CMN_ContractStartDate__c' +                                 // 契約開始日
                            ', CMN_ContractEndDate__c' +                                   // 契約終了日
                            ', CMN_ContractAgreementDate__c' +                             // 契約締結日
                            ', CMN_BidFlg__c' +                                            // 入札フラグ
                            ', CMN_TaxExemptedFlg__c' +                                    // 免税事業者フラグ
                            ', CMN_LargeCustomerFlg__c' +                                  // 大口フラグ
                            ', CMN_OldCustomerNum__c' +                                    // お客さま番号
                            ', CMN_SummaryInvoiceMasterUpdateKbn__c' +                     // 合算請求マスタ更新区分
                            ', CMN_OldJuyobasho__c' +                                      // 旧契約Juyobasho
                            ', CMN_OldJuyobasho__r.ARV_ContractStart__c' +                 // 旧契約Juyobasho.契約開始日
                            ', CMN_OldJuyobasho__r.ARV_ContractEnd__c' +                   // 旧契約Juyobasho.契約終了日
                            ', CMN_OldContractItem__c' +                                   // 旧契約商品
                            ', CMN_OldContractItem__r.CMN_ContractStartDate__c' +          // 旧契約商品.契約開始日
                            ', CMN_OldContractItem__r.CMN_ContractEndDate__c' +            // 旧契約商品.契約終了日
                            ', CMN_OldContractItem__r.CMN_QCISContractId__c' +             // 旧契約商品.QuickCIS契約番号
                            ', CMN_ContractRenewalNotificationDate__c' +                   // 契約更改通知日
                            ', CMN_ContractDetailsNotificationDate__c' +                   // 契約内容通知日
                            ', CMN_PowerAmountMeasuringType__c' +                          // 検針区分
                            ', CMN_RenewableEnergiesExemptionRate__c' +                    // 再エネ減免率
                            ', CMN_DisasterMeasureStartDate__c' +                          // 災害特措適用開始日
                            ', CMN_DisasterMeasureEndDate__c' +                            // 災害特措適用終了日
                            ', CMN_NextMaterReadingDate__c' +                              // 次回検針日
                            ', CMN_SpecifiedMonthBillCreateDate__c' +                      // 指定月請求作成年月
                            ', CMN_BillMonthCreateSts__c' +                                // 請求月毎作成ステータス
                            ', CMN_UnitPriceKbn__c' +                                      // 単価情報
                            ', CMN_PeakLoadVCharge__c' +                                   // ピークロード電力(kW)
                            ', CMN_TransferAccountNum__c' +                                // 振込先口座番号
                            ', CMN_DivisionRate__c' +                                      // 分割時割合
                            ', CMN_DivisionNum__c' +                                       // 分割数
                            ', CMN_DivisionBillingFlg__c' +                                // 分割請求フラグ
                            ', CMN_BeseLoadVCharge__c' +                                   // ベースロード電力(kW)
                            ', CMN_CombineBillingFlg__c' +                                 // まとめ請求フラグ
                            ', CMN_VisualizationCustomerNum__c' +                          // 見える化まとめコード
                            ', CMN_LateInterestRoundPosition__c' +                         // 延滞利息端数処理位置
                            ', CMN_LateInterestRoundMethod__c' +                           // 延滞利息端数処理方法
                            ', CMN_LateInterestRate__c' +                                  // 延滞利息率（％）
                            ', CMN_SpecialAgreementGroupNo__c' +                           // 企業特約グループ番号
                            ', CMN_FixedPowerFactorRate__c' +                              // 協定力率(％)
                            ', CMN_IndustryHeavyConsumption__c' +                          // 業種(多消費)_営料
                            ', CMN_IndustryName__c' +                                      // 業種_営料
                            ', CMN_IndustryCode__c' +                                      // 業種コード3桁
                            ', CMN_IndustryCode7__c' +                                     // 業種コード7桁
                            ', CMN_Industry__c' +                                          // 業種及び用途
                            ', CMN_IndustryPurposeUseOthers__c' +                          // 業種及び用途（その他記入欄）
                            ', CMN_BusinessType__c' +                                      // 業務種別
                            ', CMN_IndustryKbn__c' +                                       // 業務用/産業用区分の値に応じて対応
                            ', CMN_DemandLocationMail__c' +                                // 契約場所_メールアドレス
                            ', CMN_DemandLocationBuildingName__c' +                        // 契約場所_建物名
                            ', CMN_DemandLocationBlock3__c' +                              // 契約場所_号
                            ', CMN_DemandLocationCity__c' +                                // 契約場所_市区郡町村
                            ', CMN_DemandLocationCityCode__c' +                            // 契約場所_市区郡町村_JISコード
                            ', CMN_DemandLocationBlock1__c' +                              // 契約場所_字・丁目
                            ', CMN_DemandLocationBlockCode__c' +                           // 契約場所_字・丁目_JISコード
                            ', CMN_DemandLocationSection__c' +                             // 契約場所_大字・町名
                            ', CMN_DemandLocationSectionCode__c' +                         // 契約場所_大字・通称_JISコード
                            ', CMN_DemandLocationMobilePhone__c' +                         // 契約場所_第二連絡先
                            ', CMN_DemandLocationPhoneKbn2__c' +                           // 契約場所_第二連絡先区分
                            ', CMN_DemandLocationTellPhone__c' +                           // 契約場所_第一連絡先
                            ', CMN_DemandLocationPhoneKbn1__c' +                           // 契約場所_第一連絡先区分
                            ', CMN_DemandLocationState__c' +                               // 契約場所_都道府県
                            ', CMN_DemandLocationStateCode__c' +                           // 契約場所_都道府県_JISコード
                            ', CMN_DemandLocationBuildingNum__c' +                         // 契約場所_棟番号
                            ', CMN_DemandLocationBlock2__c' +                              // 契約場所_番地
                            ', CMN_DemandLocationRoomNum__c' +                             // 契約場所_部屋番号
                            ', CMN_DemandLocationLastName__c' +                            // 契約場所_名義(姓)
                            ', CMN_DemandLocationLastNameKana__c' +                        // 契約場所_名義(姓)_カナ
                            ', CMN_DemandLocationFirstName__c' +                           // 契約場所_名義(名)
                            ', CMN_DemandLocationFirstNameKana__c' +                       // 契約場所_名義(名)_カナ
                            ', CMN_DemandLocationPostalCode__c' +                          // 契約場所_郵便番号
                            ', CMN_PowerContract__c' +                                     // 契約電力(kW)
                            ', CMN_PowerContractProcess__c' +                              // 契約電力決定方式
                            ', CMN_AcutualMaterReadingDate__c' +                           // 計量日
                            ', CMN_MaterReadingDate__c' +                                  // 検針基準日
                            ', CMN_RenewableEnergiesStartPeriod__c' +                      // 減免率適用開始期間
                            ', CMN_RenewableEnergiesEndPeriod__c' +                        // 減免率適用終了期間
                            ', CMN_DisasterMeasureKbn__c' +                                // 災害特措区分
                            ', CMN_PayDeadlinePlusDays__c' +                               // 支払期限プラス日数（暦日）
                            ', CMN_PrivatePowerSupplyFlg__c' +                             // 自家発補給電力の有無
                            ', CMN_SelfSupplyHighVCharge__c' +                             // 自家補契約電力(kW)
                            ', CMN_SupplyDemandStartDate__c' +                             // 需給開始日
                            ', CMN_StartApplyDate__c' +                                    // 適用開始日
                            ', CMN_EndApplyDate__c' +                                      // 適用終了日
                            ', CMN_BillCustomerNum__c' +                                   // 請求まとめコード
                            ', CMN_StoreCode__c' +                                         // 店所コード
                            ', CMN_SupplyVoltage__c' +                                     // 電圧(V)
                            ', CMN_BillingMail__c' +                                       // 郵送先_メールアドレス
                            ', CMN_BillingBuildingName__c' +                               // 郵送先_建物名
                            ', CMN_BillingBlock3__c' +                                     // 郵送先_号
                            ', CMN_BillingCity__c' +                                       // 郵送先_市区郡町村
                            ', CMN_BillingCityCode__c' +                                   // 郵送先_市区郡町村_JISコード
                            ', CMN_BillingBlock1__c' +                                     // 郵送先_字・丁目
                            ', CMN_BillingBlockCode__c' +                                  // 郵送先_字・丁目_JISコード
                            ', CMN_BillingSection__c' +                                    // 郵送先_大字・町名
                            ', CMN_BillingSectionCode__c' +                                // 郵送先_大字・通称_JISコード
                            ', CMN_BillingTellPhone__c' +                                  // 郵送先_第一連絡先
                            ', CMN_BillingPhoneKbn1__c' +                                  // 郵送先_第一連絡先区分
                            ', CMN_BillingState__c' +                                      // 郵送先_都道府県
                            ', CMN_BillingStateCode__c' +                                  // 郵送先_都道府県_JISコード
                            ', CMN_BillingBuildingNum__c' +                                // 郵送先_棟番号
                            ', CMN_BillingBlock2__c' +                                     // 郵送先_番地
                            ', CMN_BillingRoomNum__c' +                                    // 郵送先_部屋番号
                            ', CMN_BillingLastName__c' +                                   // 郵送先_名義(姓)
                            ', CMN_BillingLastNameKana__c' +                               // 郵送先_名義(姓)_カナ
                            ', CMN_BillingFirstName__c' +                                  // 郵送先_名義(名)
                            ', CMN_BillingFirstNameKana__c' +                              // 郵送先_名義(名)_カナ
                            ', CMN_BillingPostalCode__c' +                                 // 郵送先_郵便番号
                            ', CMN_MailingContents__c' +                                   // 郵送内容
                            ', CMN_BasicUnitPrice__c' +                                    // 基本料金単価
                            ', CMN_ElectricityUnitPrice__c' +                              // 電力量料金単価（円/kWh）
                            ', CMN_ElectricityUnitPriceMorning__c' +                       // 電力量料金単価（朝）（円/kWh）
                            ', CMN_ElectricityUnitPriceAfternoon__c' +                     // 電力量料金単価（昼）（円/kWh）
                            ', CMN_ElectricityUnitPriceEvening__c' +                       // 電力量料金単価（晩）（円/kWh）
                            ', CMN_ElectricityUnitPriceNightHoliday__c' +                  // 電力量料金単価（夜・日曜/祝日）（円/kWh）
                            ', CMN_ElectricityUnitPricePeak__c' +                          // 電力量料金単価（ピーク）（円/kWh）
                            ', CMN_ElectricityUnitPriceSummerDay__c' +                     // 電力量料金単価（夏季昼間）（円/kWh）
                            ', CMN_ElectricityUnitPriceOtherDay__c' +                      // 電力量料金単価（他季昼間）（円/kWh）
                            ', CMN_ElectricityUnitPriceDaytime__c' +                       // 電力量料金単価（昼間）（円/kWh）
                            ', CMN_ElectricityUnitPriceNight__c' +                         // 電力量料金単価（夜間）（円/kWh）
                            ', CMN_ElectricityUnitPriceHoliday__c' +                       // 電力量料金単価（日曜/祝日）（円/kWh）
                            ', CMN_ElectricityUnitPriceSummer__c' +                        // 電力量料金単価（夏季）（円/kWh）
                            ', CMN_ElectricityUnitPriceOther__c' +                         // 電力量料金単価（その他季）（円/kWh）
                            ', CMN_AccountChargeItemMasterInfo__c' +                       // 設定料金アイテム（需要家別）情報
                            ', CMN_ConnectionServiceMenu__c' +                             // 接続送電サービスメニュー
                            ', CMN_IndividualUnitPriceFlg__c' +                            // 個別単価フラグ
                            ', CMN_ReserveSupplyCapacity__c' +                             // 予備線契約時容量
                            ', CMN_ReservePowerCapacity__c' +                              // 予備電源契約時容量
                            ', CMN_DifferentSupplyVoltageFlg__c' +                         // 異電圧予備フラグ
                            ', CMN_InstrumentsId__c' +                                     // 計器ID
                            ', CMN_BeforeReplacementInstrumentsId__c' +                    // 取替前計器ID
                            ', CMN_LinkageManagementSfid__c' +                             // IF連携OBJのSFID
                            ', CMN_DeleteContractItem__c' +                                // 複製廃止契約商品
                            ', CMN_ReproduceContractItem__c' +                             // 複製契約商品
                            ', CMN_ContinuedUseFlg__c' +                                   // 継続利用フラグ
                            ', CMN_PaymentInfo__r.Id' +                                    // 支払情報.ID
                            ', CMN_PaymentInfo__r.CMN_TransferDetailKbn__c' +              // 支払情報.振込詳細区分
                            ', CMN_PaymentInfo__r.CMN_DepositType__c' +                    // 支払情報.預金種別
                            ', CMN_PaymentInfo__r.CMN_FinancialInstName__c ' +             // 支払情報.金融機関名
                            ', CMN_PaymentInfo__r.CMN_BankDetailID__c' +                   // 支払情報.銀行詳細ID
                            ', CMN_PaymentInfo__r.CMN_BankAccMatchSts__c' +                // 支払情報.口座照合ステータス
                            ', CMN_PaymentInfo__r.CMN_BankAccTransferMethod__c' +          // 支払情報.口座振替方法
                            ', CMN_PaymentInfo__r.CMN_BankAccFirstName__c' +               // 支払情報.口座名義1
                            ', CMN_PaymentInfo__r.CMN_BankAccSecondName__c ' +             // 支払情報.口座名義2
                            ', CMN_PaymentInfo__r.CMN_BankAccNameKana__c' +                // 支払情報.口座名義カナ
                            ', CMN_PaymentInfo__r.CMN_BankAccNameKana2__c' +               // 支払情報.口座名義カナ2
                            ', CMN_PaymentInfo__r.CMN_PaymentMethod__c' +                  // 支払情報.支払方法
                            ', CMN_PaymentInfo__r.CMN_BranchCd__c ' +                      // 支払情報.店舗コード 
                            ', CMN_PaymentInfo__r.CMN_BranchName__c' +                     // 支払情報.店舗名 
                            ', CMN_PaymentInfo__r.CMN_CombinedBillingDeadline__c' +        // 支払情報.合算請求締め日
                            ', CMN_PaymentInfo__r.CMN_FinancialInstCd__c' +                // 支払情報.金融機関コード 
                            ', CMN_PaymentInfo__r.CMN_TransferDesignatedDate__c' +         // 支払情報.口座振替指定日
                            ', CMN_PaymentInfo__r.CMN_EpSfdc_PaymentInfoKey__c' +          // 支払情報.支払情報キー
                            ', CMN_PaymentInfo__r.CMN_PassbookNumUpper1Digit__c' +         // 支払情報.ゆうちょ通帳番号上1桁
                            ', CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c' +               // 支払情報.合算請求ID
                            ', CMN_PaymentInfo__r.CMN_InvoiceMethod__c' +                  // 支払情報.請求方式
                            ', CMN_PaymentInfo__r.CMN_BillingDetailNoDisplayFlg__c' +      // 支払情報.請求明細非表示フラグ
                            ', CMN_PaymentInfo__r.CMN_PaymentCondition__c' +               // 支払情報.支払条件
                            ', CMN_DeleteContractItem__r.CMN_QCISContractId__c' +          // 複製廃止契約商品.QuickCIS契約番号
                            /** PRICE_REVISION_2025-1609 USE ADD START **/
                            ', CMN_PaymentInfo__r.CMN_NotificationMethod__c' +             // 通知方法
                            ', CMN_PaymentInfo__r.CMN_BizTepcoAccountInformationView__c' + // ビジTEP口座情報出力希望フラグ
                            // ', CMN_ContractTypeKbn__c' +                                // 契約種別区分
                            ', CMN_ContractTypeKbnLink__c' +                               // 契約種別区分                            
                            ', CMN_EPPowerDiv__c' +                                        // EP電力区分
                            ', CMN_ContractUsagePeriodEnd1__c' +                           // 契約電気使用終了日1
                            ', CMN_ContractUsagePeriodEnd2__c' +                           // 契約電気使用終了日2
                            ', CMN_ContractUsagePeriodEnd3__c' +                           // 契約電気使用終了日3
                            ', CMN_ContractUsagePeriodEnd4__c' +                           // 契約電気使用終了日4
                            ', CMN_ContractUsagePeriodEnd5__c' +                           // 契約電気使用終了日5
                            ', CMN_ContractUsagePeriodEnd6__c' +                           // 契約電気使用終了日6
                            ', CMN_ContractUsagePeriodStart1__c' +                         // 契約電気使用開始日1
                            ', CMN_ContractUsagePeriodStart2__c' +                         // 契約電気使用開始日2
                            ', CMN_ContractUsagePeriodStart3__c' +                         // 契約電気使用開始日3
                            ', CMN_ContractUsagePeriodStart4__c' +                         // 契約電気使用開始日4
                            ', CMN_ContractUsagePeriodStart5__c' +                         // 契約電気使用開始日5
                            ', CMN_ContractUsagePeriodStart6__c' +                         // 契約電気使用開始日6
                            // ', CMN_FuelAdjustmentUnitKbn__c' +                          // 燃調単価識別区分
                            ', CMN_FuelAdjustmentUnitKbnLink__c' +                         // 燃調単価識別区分
                            ', CMN_FinalBillingMonth__c' +                                 // 最終請求月分
                            // ', CMN_MarketAdjustmentUnitKbn__c' +                        // 市場調整単価識別区分
                            ', CMN_MarketAdjustmentUnitKbnLink__c' +                       // 市場調整単価識別区分                            
                            ', CMN_Maximumdemandelectricity1__c' +                         // (米麦・付帯外用)最大需要電力-1月(初期契約時)
                            ', CMN_Maximumdemandelectricity10__c' +                        // (米麦・付帯外用)最大需要電力-10月(初期契約時)
                            ', CMN_Maximumdemandelectricity11__c' +                        // (米麦・付帯外用)最大需要電力-11月(初期契約時)
                            ', CMN_Maximumdemandelectricity2__c' +                         // (米麦・付帯外用)最大需要電力-2月(初期契約時)
                            ', CMN_Maximumdemandelectricity3__c' +                         // (米麦・付帯外用)最大需要電力-3月(初期契約時)
                            ', CMN_Maximumdemandelectricity4__c' +                         // (米麦・付帯外用)最大需要電力-4月(初期契約時)
                            ', CMN_Maximumdemandelectricity5__c' +                         // (米麦・付帯外用)最大需要電力-5月(初期契約時)
                            ', CMN_Maximumdemandelectricity6__c' +                         // (米麦・付帯外用)最大需要電力-6月(初期契約時)
                            ', CMN_Maximumdemandelectricity7__c' +                         // (米麦・付帯外用)最大需要電力-7月(初期契約時)
                            ', CMN_Maximumdemandelectricity8__c' +                         // (米麦・付帯外用)最大需要電力-8月(初期契約時)
                            ', CMN_Maximumdemandelectricity9__c' +                         // (米麦・付帯外用)最大需要電力-9月(初期契約時)
                            ', CMN_SupplyPointSpecificNumRiceWheat__c' +                   // 供給地点特定番号（米麦：常時）
                            /** PRICE_REVISION_2025-1609 USE ADD END **/
                        ' FROM CMN_ContractItem__c' + 
                        // 取得条件：以下の全てに該当
                        // ・契約商品.連携ステータスが"連携可能"
                        // ・契約商品.連携処理区分が"Create"
                        // ・契約商品.商品IDが連携対象
                        // ・（親）契約商品.紐づけ元契約商品がnull （子）契約商品.紐づけ元契約商品がnullでない
                        // ・（分割先以外）契約商品.分割元契約商品がnull （分割先）契約商品.分割元契約商品がnullでない
                        ' WHERE CMN_LinkSts__c = \'' + LINKSTS_ABLE + '\'' +
                        ' AND CMN_LinkageKbn__c IN (\'' +  String.join(linkageKbnSet, '\',\'') + '\')' +
                        ' AND CMN_StockKeepingUnit__c IN (\'' +  String.join(skuIdSet, '\',\'') + '\')' +
                        ' AND CMN_LinkedSourceContractItem__c ' + hasLinkedSource +
                        ' AND CMN_DivisionSource__c ' + hasDivisionSource +
                        // 並び順：
                        // 申込商品.異動日の昇順、申込商品.申込商品番号の昇順
                        ' ORDER BY CMN_OrderItem__r.CMN_TransferDate__c ASC, CMN_OrderItem__r.Name ASC';
        return query;
    }


    /**
     * QuickCISからレコードタイプ（取引先、※電力契約）を取得
     * 取得時にエラーが発生した場合はnullを返す
     * @param accessToken アクセストークン
     * @return Map<String, Map<String, String>> QuickCISレコードタイプ
     * @throws なし
     * @see なし
     */
    public Map<String, Map<String, String>> getQcisRecordType(String accessToken) {

        // レコードタイプマップ
        Map<String, Map<String, String>> qcisRecordTypeMap = new Map<String, Map<String, String>>();
        // QuickCISレコードタイプを取得（対象レコード：取引先、※電力契約）
        Integer statusCode;
        try {
            // 取得クエリを生成
            String query = 'SELECT+' +
                                'Id,+' +            // ID
                                'DeveloperName,+' + // API参照名
                                'SobjectType+' +    // オブジェクト名
                            'FROM+RecordType+' +
                            'WHERE+SObjectType+IN(\'Account\',\'dcis2__Contract__c\')';

            // GETリクエスト送信
            HttpResponse getRes;
            if(Test.isRunningTest()) {
                String pattern = this.resPattern.contains('getQcisRecordType') ? this.resPattern.split('_')[1] : 'getQcisRecordType';
                getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, null).respond(new HTTPRequest());
            }else {
                getRes = APIRequest.sendGetRequest(accessToken, query);
            }

            // リクエスト成功の場合、取得結果をマップに格納
            if(getRes.getStatusCode() == 200) {
                qcisRecordTypeMap = deserializeRtMap(getRes.getBody());
            }
        }catch(Exception e) {
            System.debug(e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString());
        }
        return qcisRecordTypeMap;
    }


    /**
     * QuickCISから※料金メニューを取得
     * 取得時にエラーが発生した場合はnullを返す
     * @param accessToken アクセストークン
     * @return Map<String, Map<String, String>> ※料金メニュー
     * @throws なし
     * @see なし
     */
    public Map<String, String> getQcisChargeMenu(String accessToken) {

        // ※料金メニューマップ
        Map<String, String> qcisChargeMenuMap = new Map<String, String>();
        // QuickCIS※料金メニューを取得
        Integer statusCode;
        try {
            // 取得クエリを生成
            String query = 'SELECT+' +
                                'Id,+' +                      // ID
                                'Name,+' +                    // 料金メニュー名
                                'C_ChargeMenuProductID__c+' + // 商品ID
                            'FROM+dcis2__ChargeMenu__c+' +
                            'WHERE+C_ChargeMenuProductID__c+!=+null';

            // GETリクエスト送信
            HttpResponse getRes;
            if(Test.isRunningTest()) {
                String pattern = this.resPattern.contains('getQcisChargeMenu') ? this.resPattern.split('_')[1] : 'getQcisChargeMenu';
                getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, null).respond(new HTTPRequest());
            }else {
                getRes = APIRequest.sendGetRequest(accessToken, query);
            }

            // リクエスト成功の場合、取得結果をマップに格納
            if(getRes.getStatusCode() == 200) {
                qcisChargeMenuMap = deserializeChargeMenuMap(getRes.getBody());
            }
        }catch(Exception e) {
            System.debug(e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString());
        }
        return qcisChargeMenuMap;
    }


    /**
     * QuickCISから取引先を取得
     * 取得時にエラーが発生した場合はnullを返す
     * @param accessToken アクセストークン
     * @param qcisCustomerNoSet CISお客様番号セット
     * @param invokeBatch 呼び出し先のバッチ名
     * @return Map<String, CMN_QuickCISRecord> QuickCIS取引先
     * @throws なし
     * @see なし
     */
    public Map<String, CMN_QuickCISRecord> getQcisAccount(String accessToken, Set<String> qcisCustomerNoSet, String invokeBatch) {

        // 取引先マップ
        Map<String, CMN_QuickCISRecord> qcisMap;
        // QuickCIS取引先を取得
        if(!qcisCustomerNoSet.isEmpty()) {
            try {
                // 取得クエリを生成
                String query = 'SELECT+' +
                                    'Id,+' +                 // ID
                                    'dcis2__AccountId__c+' + // ※CISお客様番号
                                'FROM+Account+' +
                                'WHERE+dcis2__AccountId__c+IN+(\'' + String.join(qcisCustomerNoSet, '\',\'') + '\')';
                // GETリクエスト送信
                HttpResponse getRes;
                if(Test.isRunningTest()) {
                    // 見える化まとめコード不一致バッチが呼び出し元の場合
                    if(CONTRACT_QUICKCIS_VSCSTMNM_BATCH.equals(invokeBatch)){
                       String pattern = this.resPattern.contains('getQcisAccount2') ? this.resPattern.split('_')[1] : 'getQcisAccount2';
                       getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, qcisCustomerNoSet.size()).respond(new HTTPRequest());
                    // 契約QuickCIS連携バッチ(親)が呼び出し元の場合
                    } else {
                        String pattern = this.resPattern.contains('getQcisAccount') ? this.resPattern.split('_')[1] : 'getQcisAccount';
                        getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, qcisCustomerNoSet.size()).respond(new HTTPRequest());
                    }
                } else {
                    getRes = APIRequest.sendGetRequest(accessToken, query);
                }
                // リクエスト成功の場合、取得結果をマップに格納
                if(getRes.getStatusCode() == 200) {
                    qcisMap = new Map<String, CMN_QuickCISRecord>();
                    QCIS_RecordRes result = (QCIS_RecordRes)JSON.deserialize(
                        getRes.getBody().remove('__c').remove('dcis2__'), QCIS_RecordRes.class);

                    for(CMN_QuickCISRecord resRec : result.records) {
                        qcisMap.put(resRec.AccountId, resRec);
                    }
                }
            }catch(Exception e) {
                System.debug(e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString());
                qcisMap = null;
            }
        }
        return qcisMap;
    }


    /**
     * QuickCISから※電力契約を取得
     * 取得時にエラーが発生した場合はnullを返す
     * @param accessToken アクセストークン
     * @param qcisRecordTypeMap QuickCISレコードタイプマップ
     * @param cntrIdSet 契約番号セット
     * @param idFieldName キー項目名
     * @return Map<String, CMN_QuickCISRecord> QuickCIS※電力契約
     * @throws なし
     * @see なし
     */
    public Map<String, CMN_QuickCISRecord> getQcisContract(String accessToken,
     Map<String, Map<String, String>> qcisRecordTypeMap, Set<String> cntrIdSet, String idFieldName) {

        // ※電力契約マップ  Map<idFieldName, ※電力契約>
        Map<String, CMN_QuickCISRecord> qcisMap;
        // QuickCIS※電力契約を取得
        try {
            // レコードタイプID「主契約（高圧）」をマップから取得
            String rtId = qcisRecordTypeMap.get('dcis2__Contract__c').get('MainHighV');
            // 取得クエリを生成
            String query = 'SELECT+' +
                                'Id,+' +                                        // ID
                                'Name,+' +                                      // 契約番号
                                // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
                                'C_ContinuedUseMigrationStatus__c,+' +          // 継続利用契約データ移行状況
                                // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End
                                'dcis2__Member__c,+' +                          // 会員
                                'C_DifferentCapacitySpareRequestFlg__c,+' +     // 異容量フラグ
                                'dcis2__HighVPowerContract__c,+' +              // 高圧契約電力(kW)
                                'dcis2__ReserveHighVCharge__c,+' +              // 予備線契約電力(kW)
                                'C_ReserveLineBaseContractCapacity__c,+' +      // 予備線契約時容量
                                'dcis2__StandbyPowerCharge__c,+' +              // 予備電源契約電力(kW)
                                'C_ReservePowerContractCapacity__c,+' +         // 予備電源契約時容量
                                'C_StandbyPowerChargeSecond__c,+' +             // 第二予備電源契約電力(kW)
                                'C_ReservePowerContractCapacitySecond__c,+' +   // 第二予備電源契約時容量
                                'C_AncillaryServiceCapacity__c,+' +             // アンシラリーサービス料金契約容量(kW）
                                'C_SummaryInvoiceID__c,+' +                     // 合算請求ID
                                'dcis2__ContractEndDate__c+' +                  // 契約終了日
                            'FROM+dcis2__Contract__c+' +
                            'WHERE+RecordTypeId+=+\'' + rtId + '\'+' +
                            'AND+' + idFieldName + '+IN+(\'' + String.join(cntrIdSet, '\',\'') + '\')';
            // GETリクエスト送信
            HttpResponse getRes;
            if(Test.isRunningTest()) {
                String pattern = this.resPattern.contains('getQcisContract') ? this.resPattern.split('_')[1] : 'getQcisContract';
                getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, cntrIdSet.size()).respond(new HTTPRequest());
            }else {
                getRes = APIRequest.sendGetRequest(accessToken, query);
            }
            // リクエスト成功の場合、取得結果をマップに格納
            if(getRes.getStatusCode() == 200) {
                qcisMap = new Map<String, CMN_QuickCISRecord>();
                QCIS_RecordRes result = (QCIS_RecordRes)JSON.deserialize(
                    getRes.getBody().remove('__c').remove('dcis2__').remove('C_'), QCIS_RecordRes.class);

                for(CMN_QuickCISRecord resRec : result.records) {
                    // 引数のidFieldNameによりキー項目を変更
                    if(idFieldName == 'Name') {
                        qcisMap.put(resRec.Name, resRec);
                    }else {
                        qcisMap.put(resRec.Id, resRec);
                    }
                }
            }
        }catch(Exception e) {
            System.debug(e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString());
            qcisMap = null;
        }
        return qcisMap;
    }


    /**
     * QuickCISから※I/F連携情報を取得
     * 取得時にエラーが発生した場合はnullを返す
     * @param accessToken アクセストークン
     * @param qcisLnkgMngIdSet IF連携IDセット
     * @return Map<String, CMN_QuickCISRecord> QuickCIS※I/F連携情報
     * @throws なし
     * @see なし
     */
    public Map<String, CMN_QuickCISRecord> getQcisLinkageManagement(String accessToken, Set<String> qcisLnkgMngIdSet) {

        // ※I/F連携情報マップ
        Map<String, CMN_QuickCISRecord> qcisMap;
        // QuickCIS※I/F連携情報を取得
        try {
            // 取得クエリを生成
            String query = 'SELECT+Id,+dcis2__Contract__c+' +
                            'FROM+dcis2__LinkageManagement__c+' +
                            'WHERE+Id+IN+(\'' + String.join(qcisLnkgMngIdSet, '\',\'') + '\')';
            // GETリクエスト送信
            HttpResponse getRes;
            if(Test.isRunningTest()) {
                String pattern = this.resPattern.contains('getQcisLinkageManagement') ? this.resPattern.split('_')[1] : 'getQcisLinkageManagement';
                getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, qcisLnkgMngIdSet.size()).respond(new HTTPRequest());
            }else {
                getRes = APIRequest.sendGetRequest(accessToken, query);
            }
            // リクエスト成功の場合、取得結果をマップに格納
            if(getRes.getStatusCode() == 200) {
                qcisMap = new Map<String, CMN_QuickCISRecord>();
                QCIS_RecordRes result = (QCIS_RecordRes)JSON.deserialize(
                    getRes.getBody().remove('__c').remove('dcis2__'), QCIS_RecordRes.class);

                for(CMN_QuickCISRecord resRec : result.records) {
                    qcisMap.put(resRec.Id, resRec);
                }
            }
        }catch(Exception e) {
            System.debug(e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString());
            qcisMap = null;
        }
        return qcisMap;
    }

    /**
     * QuickCISから設定料金アイテム（需要家別）マスタを取得
     * 取得時にエラーが発生した場合はnullを返す
     * @param accessToken アクセストークン
     * @param qcisAccChargeItemMstIdSet IF連携IDセット
     * @return Map<String, CMN_QuickCISRecord> QuickCIS※I/F連携情報
     * @throws なし
     * @see なし
     */
    public Map<String, CMN_QuickCISRecord> getQcisAccountChargeItemMaster(String accessToken, Set<String> qcisAccChargeItemMstIdSet) {

        // ※I/F連携情報マップ
        Map<String, CMN_QuickCISRecord> qcisMap;
        // QuickCIS設定料金アイテム（需要家別）マスタを取得
        try {
            // 取得クエリを生成
            String query = 'SELECT+Id+' +
                            'FROM+C_AccountChargeItemMaster__c+' +
                            'WHERE+Id+IN+(\'' + String.join(qcisAccChargeItemMstIdSet, '\',\'') + '\')';
            // GETリクエスト送信
            HttpResponse getRes;
            if(Test.isRunningTest()) {
                String pattern = this.resPattern.contains('getQcisAccountChargeItemMaster') ? this.resPattern.split('_')[1] : 'getQcisAccountChargeItemMaster';
                getRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, qcisAccChargeItemMstIdSet.size()).respond(new HTTPRequest());
            }else {
                getRes = APIRequest.sendGetRequest(accessToken, query);
            }
            // リクエスト成功の場合、取得結果をマップに格納
            if(getRes.getStatusCode() == 200) {
                qcisMap = new Map<String, CMN_QuickCISRecord>();
                QCIS_RecordRes result = (QCIS_RecordRes)JSON.deserialize(
                    getRes.getBody().remove('__c').remove('dcis2__'), QCIS_RecordRes.class);

                for(CMN_QuickCISRecord resRec : result.records) {
                    qcisMap.put(resRec.Id, resRec);
                }
            }
        }catch(Exception e) {
            System.debug(e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString());
            qcisMap = null;
        }
        return qcisMap;
    }

    
    /**
     * 契約商品と※電力契約の整合性チェック（親）
     * ・契約商品.連携処理区分が"Create"：※電力契約が作成済みの場合はエラー
     * ・契約商品.連携処理区分が"Update","Delete"：QuickCIS契約番号がnullの場合はエラー、※電力契約が未作成の場合はエラー
     * @param ci ARVE契約商品
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @return CMN_ContractItem__c ARVE契約商品
     * @throws なし
     * @see なし
     */
    public CMN_ContractItem__c checkContractItem(CMN_ContractItem__c ci, Map<String, CMN_QuickCISRecord> qcisCntrMap) {

        // ※電力契約マップから契約商品.QuickCIS契約番号をキーに※電力契約を取得
        CMN_QuickCISRecord qcisCntr = qcisCntrMap.get(ci.CMN_QCISContractId__c);

        String errMsg;
        // 契約商品.連携処理区分が"Create"
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C) {
            // ※電力契約が作成済み かつ QuickCIS契約番号の継続利用対象ではない場合、エラーメッセージを設定
            if(qcisCntr != null && !ci.CMN_ContinuedUseFlg__c) {
                errMsg = LINKERRORDETAIL_DONE;
            // 契約商品.QuickCIS契約番号がnull かつ QuickCIS契約番号の継続利用対象の場合、エラーメッセージを設定
            } else if (ci.CMN_QCISContractId__c == null && ci.CMN_ContinuedUseFlg__c) {
                errMsg = LINKERRORDETAIL_NOQCISID;
            // 契約商品.QuickCIS契約番号がnull かつ QuickCIS契約番号の継続利用対象の場合、エラーメッセージを設定
            } else if (qcisCntr == null && ci.CMN_ContinuedUseFlg__c) {
                errMsg = LINKERRORDETAIL_NONE;
            }
        // 契約商品.連携処理区分が"Create"以外（"Update","Delete"）
        }else {
            // 契約商品.QuickCIS契約番号がnullの場合、エラーメッセージを設定
            if(ci.CMN_QCISContractId__c == null) {
                errMsg = LINKERRORDETAIL_NOQCISID;
            // ※電力契約が未作成の場合、エラーメッセージを設定
            }else if(qcisCntr == null) {
                errMsg = LINKERRORDETAIL_NONE;
            }
        }

        // エラーメッセージを設定（エラーがない場合はnullが設定される）
        ci.CMN_LinkErrorDetail__c = errMsg; // 連携エラー内容
        // エラーの場合は、ステータスを連携エラーに更新
        if(errMsg != null) {
            ci.CMN_LinkSts__c = LINKSTS_ERR; // 連携ステータス
        }
        return ci;
    }


    /**
     * 契約商品とQuickCIS設定料金アイテム（需要家別）マスタの整合性チェック（子）
     * ・契約商品.連携処理区分が"Create"：契約商品.設定料金アイテム（需要家別）情報に値がある場合はエラー
     * ・契約商品.連携処理区分が"Update","Delete"：契約商品.設定料金アイテム（需要家別）情報が空白の場合はエラー
     * @param ci ARVE契約商品
     * @return CMN_ContractItem__c ARVE契約商品
     * @throws なし
     * @see なし
     */
    public CMN_ContractItem__c checkContractItemChild(CMN_ContractItem__c ci) {

        String errMsg;
        // 契約商品.連携処理区分が"Create"
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C) {
            // 契約商品.設定料金アイテム（需要家別）情報に値がある場合、エラーメッセージを設定
            if(!String.isBlank(ci.CMN_AccountChargeItemMasterInfo__c)) {
                errMsg = '設定料金アイテム（需要家別）情報が入力されている';
            }
        // 契約商品.連携処理区分が"Create"以外（"Update","Delete"）
        }else {
            // 契約商品.設定料金アイテム（需要家別）情報が空白の場合、エラーメッセージを設定
            if(String.isBlank(ci.CMN_AccountChargeItemMasterInfo__c)) {
                errMsg = '設定料金アイテム（需要家別）情報が入力されていない';
            }
        }

        // エラーメッセージを設定（エラーがない場合はnullが設定される）
        ci.CMN_LinkErrorDetail__c = errMsg; // 連携エラー内容
        // エラーの場合は、ステータスを連携エラーに更新
        if(errMsg != null) {
            ci.CMN_LinkSts__c = LINKSTS_ERR; // 連携ステータス
        }
        return ci;
    }
    

    /**
     * 分割元※電力契約の存在チェック
     * @param ci ARVE契約商品
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @return Boolean 分割元※電力契約が作成済みかどうか
     * @throws なし
     * @see なし
     */
    public Boolean isSourceLinked(CMN_ContractItem__c ci, Map<String, CMN_QuickCISRecord> qcisCntrMap) {

        // 分割元※電力契約
        CMN_QuickCISRecord qcisCntr;

        // 「分割元契約商品.複製契約商品」に値がある かつ「分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）」に値がある場合
        if(ci.CMN_DivisionSource__c != null &&
           ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__c != null &&
           ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c != null
        ){
            // 「分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）」に対応する「電力契約」を取得                        
                qcisCntr = qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c);
            
        // 「分割元契約商品.複製契約商品」に値がない または「分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）」に値がない場合
        }else if(ci.CMN_DivisionSource__c != null &&
           (ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__c == null ||
           ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c == null)
        ){
            // 「分割元契約商品.QuickCIS契約番号（複製後）」に値がある場合
            if(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c != null){
                // 「分割元契約商品.連携処理区分」がCreateの場合
                if(ci.CMN_DivisionSource__r.CMN_LinkageKbn__c == LINKAGEKBN_C){
                    // 「分割先契約商品.継続利用フラグ」がTRUE かつ 「分割先契約商品.連携処理区分」がDelete
                    if(ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_D){
                        // 「分割元契約商品.QuickCIS契約番号（複製後）」に対応する「電力契約」を取得
                        qcisCntr = qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c);
                    }else{
                        // 「分割元契約商品.QuickCIS契約番号」に対応する「電力契約」を取得
                        qcisCntr = qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c);
                    }
                }else{
                    // 「分割元契約商品.QuickCIS契約番号」に対応する「電力契約」を取得
                qcisCntr = qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c);   
                }
            // 「分割元契約商品.QuickCIS契約番号（複製後）」に値がない場合
            }else if(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c == null){
                // 「分割元契約商品.QuickCIS契約番号」に対応する「電力契約」を取得
                qcisCntr = qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c);
            }
        }

        // 分割元※電力契約が未作成の場合
        if(qcisCntr == null) {
           return false;
        }

        // 分割元※電力契約が作成済みの場合
        return true;
    }


    /**
     * QuickCIS取引先の作成・更新
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisRecordTypeMap QuickCISレコードタイプマップ
     * @param qcisAccMap QuickCIS取引先マップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String upsertQcisAccount(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, Map<String, String>> qcisRecordTypeMap, Map<String, CMN_QuickCISRecord> qcisAccMap) {

        // QuickCIS取引先レコードタイプマップ
        Map<String, String> acctRtMap = qcisRecordTypeMap.get('Account');

        // 作成・更新用QuickCIS取引先マップ  Map<※CISお客様番号, Map<項目名, 設定値>>
        Map<String, Map<String, String>> upsQcisAcctMap = new Map<String, Map<String, String>>();
        // CISお客様番号リスト（APIレスポンスとの突合に使用）
        List<String> qcisCstNoList = new List<String>();

        // 現在時刻
        String nowTime = DateTime.now().format('yyyyMMddHHmmss');
        
        // マッピングデータを生成
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // 見える化まとめコード
            String accountId = ci.CMN_VisualizationCustomerNum__c;
            // お客さま番号
            String oldCustomerNum = ci.CMN_OldCustomerNum__c;
            // 見える化まとめコードがnullの場合は処理をスキップ
            if(String.isBlank(accountId)) {
                continue;
            // 契約商品.連携処理区分が"Create"以外かつお客さま番号と見える化まとめコードが異なる場合は処理をスキップ
            }else if(ci.CMN_LinkageKbn__c != LINKAGEKBN_C && accountId != oldCustomerNum) {
                continue;
            }

            // QuickCIS取引先をマップから取得
            CMN_QuickCISRecord qcisAcct = qcisAccMap.get(accountId);
            // ARVE契約商品.連携処理区分が"Create"かつQuickCIS取引先が作成済みの場合は処理をスキップ
            if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C && qcisAcct != null) {
                continue;
            }

            // QuickCIS取引先が未作成かつお客さま番号と見える化まとめコードが異なる場合は連携エラーとする（ARVE-5179）
            if(qcisAcct == null && accountId != oldCustomerNum) {
                ci.CMN_LinkSts__c = LINKSTS_ERR;
                ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_CSTNUM_NOT_EQUAL_VISUALCSTNUM;
                continue;
            }

            // 作成・更新用マッピングデータを生成
            Map<String, String> mapping = mappingAccount(ci, qcisAcct, acctRtMap, nowTime);
            // 作成・更新用マップに格納
            if(upsQcisAcctMap.containsKey(accountId)) {
                upsQcisAcctMap.get(accountId).putAll(mapping);
            }else {
                upsQcisAcctMap.put(accountId, mapping);
            }
        }

        // APIリクエスト（QuickCIS取引先の作成・更新）
        String errMsg;
        if(!upsQcisAcctMap.isEmpty()) {
            // 作成・更新用JSONリスト（1件ごとの更新内容を保持）
            List<String> jsonList = new List<String>();

            // 1件ずつJSON文字列に変換
            for(String accountId : upsQcisAcctMap.keySet()) {
                Map<String, String> mapping = upsQcisAcctMap.get(accountId);
                String json = '{"attributes":{"type":"Account"}';
                for(String fieldName : mapping.keySet()) {
                    json += ',"' + fieldName + '":' + mapping.get(fieldName);
                }
                jsonList.add(json);
                qcisCstNoList.add(accountId);
            }
            // JSONを1つの文字列にマージ
            String jsonBody = '{"allOrNone":false,"records":[' + String.join(jsonList, '},') + '}]}';

            // リクエスト結果マップ
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();

            // リクエスト送信
            try {
                HttpResponse patchRes;
                // Apexテスト実行時、モックデータを返す
                if(Test.isRunningTest()) {
                    String pattern = this.resPattern.contains('upsertQcisAccount') ? this.resPattern.split('_')[1] : 'upsertQcisAccount';
                    patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, jsonList.size()).respond(new HTTPRequest());

                // APIリクエスト送信
                }else {
                    patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody, 'Account', 'Id');
                }

                // リクエスト結果をレコード単位でマップに格納
                if(patchRes.getStatusCode() == 200) {
                    List<QCIS_APIRes> patchResList = (List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class);
                    for(Integer i = 0; i < qcisCstNoList.size(); i ++) {
                        resultMap.put(qcisCstNoList[i], patchResList[i]);
                    }
                }else {
                    errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                }
            }catch(Exception e) {
                errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
            }

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // リクエスト結果がエラーの場合、ARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // マップからリクエスト結果を取り出す
                    QCIS_APIRes result = resultMap.get(ci.CMN_VisualizationCustomerNum__c);
                    // エラー発生の場合、連携エラーにする
                    if(result != null && !result.errors.isEmpty()) {
                        ci.CMN_LinkSts__c = LINKSTS_ERR;
                        ci.CMN_LinkErrorDetail__c = ('QuickCIS取引先' + LINKERRORDETAIL_FAILED + '：' + result.errors).left(255);

                    // 正常終了の場合、作成したレコードをQuickCIS取引先マップに追加
                    }else if(result != null && !qcisAccMap.containsKey(ci.CMN_VisualizationCustomerNum__c)) {
                        CMN_QuickCISRecord qcisAcct = new CMN_QuickCISRecord();
                        qcisAcct.Id = result.id;
                        qcisAccMap.put(ci.CMN_VisualizationCustomerNum__c, qcisAcct);
                    }
                }
            }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS取引先' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * QuickCIS※電力契約の作成・更新
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisRecordTypeMap QuickCISレコードタイプマップ
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @param qcisAccMap QuickCIS取引先マップ
     * @param qcisChargeMenuMap ※料金メニューマップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String upsertQcisContract(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, Map<String, String>> qcisRecordTypeMap, Map<String, CMN_QuickCISRecord> qcisCntrMap,
        Map<String, CMN_QuickCISRecord> qcisAccMap, Map<String, String> qcisChargeMenuMap) {

        // QuickCIS※電力契約レコードタイプマップ
        Map<String, String> cntrRtMap = qcisRecordTypeMap.get('dcis2__Contract__c');

        // 作成・更新用QuickCIS※電力契約マップ  Map<突合用契約商品ID, Map<項目名, 設定値>>
        Map<String, Map<String, String>> upsQcisCntrMap = new Map<String, Map<String, String>>();
        // 突合用契約商品IDリスト  QuickCIS契約番号または※ARVE契約番号（Name）を保持
        List<String> cntrIdList = new List<String>();
        // 再取得※電力契約マップ  Map<Id, ※電力契約>
        Map<String, CMN_QuickCISRecord> latestQcisCntrMap = new Map<String, CMN_QuickCISRecord>();

        // 支払情報（最新履歴）マップ
        Map<Id,CMN_PaymentInfo__c> pilhMap = getPayInfoLastHistoryMap(tgtMap);

        // マッピングデータを生成
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // 突合用のキー値にQuickCIS契約番号を格納
            String cntrId = ci.CMN_QCISContractId__c;
            // QuickCIS契約番号がnullか継続利用対象の複製契約の場合は契約番号（Name）を格納
            if (ci.CMN_QCISContractId__c == null || (ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C)) {
              cntrId = ci.Name;
            }

            // 合算請求マスタ更新区分 が "加入" 又は "脱退→加入" かつ　支払情報.合算請求ID が null の場合、連携対象外とする
            if((ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '加入' ||  ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入')
               && String.isBlank(ci.CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c)){
                ci.CMN_LinkSts__c = LINKSTS_ERR;
                ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_SUMINVOICEID;
            // 合算請求マスタ更新区分 が "脱退→新規" 又は "脱退→加入" かつ　支払情報(最新履歴レコード).請求方式 が取得できない場合、連携対象外とする
            }else if((ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→新規' ||  ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入')
               && (!pilhMap.containsKey(ci.Id) || String.isBlank(pilhMap.get(ci.Id).CMN_InvoiceMethod__c))){
                ci.CMN_LinkSts__c = LINKSTS_ERR;
                ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_INVOICEMETHOD;
            // 連携対象の場合
            }else{                
                // 作成・更新用マッピングデータを生成
                Map<String, String> mapping = mappingContract(ci, cntrRtMap, qcisAccMap, qcisCntrMap, qcisChargeMenuMap, pilhMap.get(ci.Id));
                // 作成・更新用マップに格納
                upsQcisCntrMap.put(cntrId, mapping);
            }
        }

        // APIリクエスト（QuickCIS※電力契約の作成・更新）
        String errMsg;
        if(!upsQcisCntrMap.isEmpty()) {
            // 作成・更新用JSONリスト（1件ごとの更新内容を保持）
            List<String> jsonList = new List<String>();

            // 1件ずつJSON文字列に変換
            for(String cntrId : upsQcisCntrMap.keySet()) {
                Map<String, String> mapping = upsQcisCntrMap.get(cntrId);
                String json = '{"attributes":{"type":"dcis2__Contract__c"}';
                for(String fieldName : mapping.keySet()) {
                    json += ',"' + fieldName + '":' + mapping.get(fieldName);
                }
                // 作成・更新用JSONリストに追加
                jsonList.add(json);
                // 突合用契約商品IDリストに追加
                cntrIdList.add(cntrId);
            }
            
            // JSONを1つの文字列にマージ
            String jsonBody = '{"allOrNone":false,"records":[' + String.join(jsonList, '},') + '}]}';

            // リクエスト結果マップ
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();
            // 再取得用IDセット
            Set<String> latestQcisCntrIdSet = new Set<String>();

            // リクエスト送信
            try {
                HttpResponse patchRes;
                // Apexテスト実行時、モックデータを返す
                if(Test.isRunningTest()) {
                    String pattern = this.resPattern.contains('upsertQcisContract') ? this.resPattern.split('_')[1] : 'upsertQcisContract';
                    patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, jsonList.size()).respond(new HTTPRequest());

                // APIリクエスト送信
                }else {
                    patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody, 'dcis2__Contract__c', 'Id');
                }

                // リクエスト結果をレコード単位でマップに格納
                if(patchRes.getStatusCode() == 200) {
                    List<QCIS_APIRes> patchResList = (List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class);
                    for(Integer i = 0; i < cntrIdList.size(); i ++) {
                        resultMap.put(cntrIdList[i], patchResList[i]);
                        latestQcisCntrIdSet.add(patchResList[i].id);
                        // Apexテスト実行時、再取得※電力契約マップにモックデータを格納
                        if(Test.isRunningTest()) {
                            CMN_QuickCISRecord rec = new CMN_QuickCISRecord();
                            rec.Name = 'CI-25-01-0000' + String.valueOf(i).leftPad(3, '0');
                            if(this.resPattern == 'failedGetLatestQcisCntrMap') {
                                latestQcisCntrMap = null;
                            }else {
                                if(this.resPattern == 'contractItemIllegalError') {
                                    rec.Name = rec.Name.rightPad(1000, '0');
                                }
                                latestQcisCntrMap.put(patchResList[i].id, rec);
                            }
                        }
                    }
                }else {
                    errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                }
            }catch(Exception e) {
                errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
            }

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // 作成・更新した※電力契約の再取得
                
                // 再取得用IDセットからnullを除外
                latestQcisCntrIdSet.remove(null);
                // ※電力契約を再取得
                if(!latestQcisCntrIdSet.isEmpty()) {
                    if(!Test.isRunningTest()) {
                        latestQcisCntrMap = getQcisContract(accessToken, qcisRecordTypeMap, latestQcisCntrIdSet, 'Id');
                    }
                }
                // 再取得に失敗した場合はエラー終了
                if(latestQcisCntrMap == null) {
                    errMsg = 'QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + ERRMSG002;
                    return errMsg;
                }

                // リクエスト結果が成功の場合、ARVE契約商品にQuickCIS契約番号を反映
                // リクエスト結果がエラーの場合、ARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // マップからリクエスト結果を取り出す
                    // 突合用のキー値にQuickCIS契約番号を格納
                    String cntrId = ci.CMN_QCISContractId__c;
                    // QuickCIS契約番号がnullか継続利用対象の複製契約の場合は契約番号（Name）を格納
                    if (ci.CMN_QCISContractId__c == null || (ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C)) {
                      cntrId = ci.Name;
                    }
                    QCIS_APIRes result = resultMap.get(cntrId);

                    // エラー発生の場合、連携エラーにする
                    if(result != null && !result.errors.isEmpty()) {
                        ci.CMN_LinkSts__c = LINKSTS_ERR;
                        ci.CMN_LinkErrorDetail__c = ('QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + result.errors).left(255);

                    // 正常終了の場合、ARVE契約商品へQuickCIS契約番号のバックおよび
                    // 作成したレコードをQuickCIS※電力契約マップに追加
                    }else {
                        // 連携エラーでない場合
                        if(ci.CMN_LinkSts__c != LINKSTS_ERR){
                            // 再取得した※電力契約を取り出す
                            CMN_QuickCISRecord latestQcisCntr = latestQcisCntrMap.get(result.Id);
                            if(latestQcisCntr != null) {
                                // QuickCIS契約番号の継続利用対象の複製契約以外の場合、QuickCIS契約番号を設定・更新
                                if(!(ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C)){
                                    // //ARVE契約商品.QuickCIS契約番号
                                    ci.CMN_QCISContractId__c = latestQcisCntr.Name;
                                // 2026/02/19 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start    
                                } else {                                    
                                    // 複製の契約商品を作成した時点で、初めから元の契約番号をQuickCIS契約番号に設定
                                    ci.CMN_ReproducedQCISContractId__c = latestQcisCntr.Name;
                                   
                                }
                                // 2026/02/19 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End 
                                // 作成・更新した※電力契約をQuickCIS※電力契約マップに追加
                                qcisCntrMap.put(latestQcisCntr.Name, latestQcisCntr);
                            }
                        }
                    }
                }
            }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * QuickCIS※電力契約の更新（子契約）
     * 子契約処理にて使用。親契約に紐づく※電力契約を更新する
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String updateQcisContractChild(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, CMN_QuickCISRecord> qcisCntrMap) {

        // 更新用QuickCIS※電力契約マップ  Map<QuickCIS契約番号, Map<項目名, 設定値>>
        Map<String, Map<String, String>> updQcisCntrMap = new Map<String, Map<String, String>>();

        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // 紐づけ元契約商品.QuickCIS契約番号
            String qcisCntrParentId = ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c;
            // ※電力契約（親）
            CMN_QuickCISRecord qcisCntrParent = qcisCntrMap.get(qcisCntrParentId);
            // ※電力契約（親）が取得できなかった場合、連携エラーにして処理をスキップ
            if(qcisCntrParent == null) {
                ci.CMN_LinkSts__c = LINKSTS_ERR;
                ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_NOQCISPARENT;
                continue;
            }

            // 作成用マッピングデータを生成
            // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update Start
            //Map<String, String> mapping = mappingContractChild(ci, qcisCntrParent);
            Map<String, String> mapping = mappingContractChild(ci, qcisCntrMap);
            // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update End
            // 更新用QuickCIS※電力契約マップに格納
            if(!mapping.isEmpty()) {
                if(updQcisCntrMap.containsKey(qcisCntrParentId)) {
                    updQcisCntrMap.get(qcisCntrParentId).putAll(mapping);
                }else {
                    updQcisCntrMap.put(qcisCntrParentId, mapping);
                }
            }
        }

        // APIリクエスト（QuickCIS※電力契約の更新）
        String errMsg;
        if(!updQcisCntrMap.isEmpty()) {
            // 更新用JSONリスト（1件ごとの更新内容を保持）
            List<String> jsonList = new List<String>();

            // 1件ずつJSON文字列に変換
            for(String cntrId : updQcisCntrMap.keySet()) {
                Map<String, String> mapping = updQcisCntrMap.get(cntrId);
                String json = '{"attributes":{"type":"dcis2__Contract__c"}';
                for(String fieldName : mapping.keySet()) {
                    json += ',"' + fieldName + '":' + mapping.get(fieldName);
                }
                // 更新用JSONリストに追加
                jsonList.add(json);
            }
            
            // JSONを1つの文字列にマージ
            String jsonBody = '{"allOrNone":false,"records":[' + String.join(jsonList, '},') + '}]}';

            // リクエスト結果マップ  Map<※電力契約ID, リクエスト結果>
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();

            // リクエスト送信
            try {
                HttpResponse patchRes;
                // Apexテスト実行時、モックデータを返す
                if(Test.isRunningTest()) {
                    String pattern = this.resPattern.contains('updateQcisContractChild') ? this.resPattern.split('_')[1] : 'updateQcisContractChild';
                    patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, jsonList.size()).respond(new HTTPRequest());

                // APIリクエスト送信
                }else {
                    patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody, 'dcis2__Contract__c', 'Id');
                }

                // リクエスト結果をレコード単位でマップに格納
                if(patchRes.getStatusCode() == 200) {
                    List<QCIS_APIRes> patchResList = (List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class);
                    for(QCIS_APIRes patchResRec : patchResList) {
                        resultMap.put(patchResRec.Id, patchResRec);
                    }
                }else {
                    errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                }
            }catch(Exception e) {
                errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
            }

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // 紐づけ元契約商品.QuickCIS契約番号
                    String qcisCntrParentId = ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c;
                    // ※電力契約（親）
                    CMN_QuickCISRecord qcisCntrParent = qcisCntrMap.get(qcisCntrParentId);
                    // ※電力契約（親）が取得できなかった場合、処理をスキップ
                    if(qcisCntrParent == null) {
                        continue;
                    }
                    // ※電力契約（親）IDを元にマップからリクエスト結果を取り出す
                    QCIS_APIRes result = resultMap.get(qcisCntrParent.Id);
                    if(this.resPattern == 'updateQcisContractChild_upsertError') {
                        result = resultMap.values()[0];
                    }

                    // エラー発生の場合、連携エラーにする
                    if(result != null && !result.errors.isEmpty()) {
                        ci.CMN_LinkSts__c = LINKSTS_ERR;
                        ci.CMN_LinkErrorDetail__c = ('QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + result.errors).left(255);
                    }
                }
            }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }

    /**
     * QuickCIS※電力契約の更新（子契約）
     * 子契約処理にて使用。親契約に紐づく※電力契約の登録ステータスを更新する
     * @param tgtMap ARVE契約商品マップ
     * @param updQcisCntrIdList 更新対象の※電力契約ID
     * @param qcisCntrIdMap 契約商品IDと※電力契約（親）のマッピング
     * @param accessToken アクセストークン
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String updateQcisContractChildStatus(Map<Id, CMN_ContractItem__c> tgtMap, Set<String> updQcisCntrIdList, Map<String, String> qcisCntrIdMap, String accessToken) {
        // 作成・更新用JSONリスト（200件ごとの更新内容を保持）
        List<List<String>> wholeJsonList = new List<List<String>>();
        // 更新用JSONリスト（1件ごとの更新内容を保持）
        List<String> jsonList = new List<String>();
        
        String errMsg;

        // 作成用マッピングデータを生成
        if(!updQcisCntrIdList.isEmpty()) {
            for(String updQcisCntrId : updQcisCntrIdList) {
                String json = '{"attributes":{"type":"dcis2__Contract__c"},"Id":' + convertNull(updQcisCntrId) + ',"C_CompleteGS__c":"Temporary"';
                // 200件に到達した場合、作成・更新用JSONリストに追加
                if(jsonList.size() == 200) {
                    wholeJsonList.add(jsonList.clone());
                    jsonList.clear();
                }
                jsonList.add(json);
            }
            // 残りの分も作成・更新用JSONリストに追加
            if(!jsonList.isEmpty()) {
                wholeJsonList.add(jsonList);
            }

            // APIリクエスト（QuickCIS※電力契約の更新）
            

            // リクエスト結果マップ  Map<※電力契約ID, リクエスト結果>
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();

            // 200件ずつリクエスト送信
            List<QCIS_APIRes> patchResList = new List<QCIS_APIRes>();
            for(List<String> json200List : wholeJsonList) {
                // JSONを1つの文字列にマージ
                String jsonBody = '{"allOrNone":false,"records":[' + String.join(json200List, '},') + '}]}';
                // リクエスト送信
                try {
                    HttpResponse patchRes;
                    // Apexテスト実行時、モックデータを返す
                    if(Test.isRunningTest()) {
                        String pattern = this.resPattern.contains('updateQcisContractChild') ? this.resPattern.split('_')[1] : 'updateQcisContractChild';
                        patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, jsonList.size()).respond(new HTTPRequest());

                    // APIリクエスト送信
                    }else {
                        patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody, 'dcis2__Contract__c', 'Id');
                    }

                    // リクエスト結果をレコード単位でマップに格納
                    if(patchRes.getStatusCode() == 200) {
                        patchResList.addAll((List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class));
                        for(QCIS_APIRes patchResRec : patchResList) {
                            resultMap.put(patchResRec.Id, patchResRec);
                        }
                    }else {
                        errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                    }
                }catch(Exception e) {
                    errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
                }
            }

            

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                for(String cId : qcisCntrIdMap.keySet()) {
                    // マップから※電力契約（親）のIDを取り出す
                    String updQcisCntrId = qcisCntrIdMap.get(cId);
                    if(resultMap.containsKey(updQcisCntrId)) {
                        // ※電力契約（親）IDを元にマップからリクエスト結果を取り出す
                        QCIS_APIRes result = resultMap.get(updQcisCntrId);

                        if(this.resPattern == 'updateQcisContractChild_upsertError') {
                            result = resultMap.values()[0];
                        }

                        // エラー発生の場合、連携エラーにする
                        if(result != null && !result.errors.isEmpty()) {
                            tgtMap.get(cId).CMN_LinkSts__c = LINKSTS_ERR;
                            tgtMap.get(cId).CMN_LinkErrorDetail__c = ('QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + result.errors).left(255);
                        }
                    }
                }
            }
        }

        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * QuickCIS※電力契約の作成・更新（分割先契約）
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisRecordTypeMap QuickCISレコードタイプマップ
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @param qcisAccMap QuickCIS取引先マップ
     * @param qcisChargeMenuMap ※料金メニューマップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String upsertQcisContractDivision(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, Map<String, String>> qcisRecordTypeMap, Map<String, CMN_QuickCISRecord> qcisCntrMap,
        Map<String, CMN_QuickCISRecord> qcisAccMap, Map<String, String> qcisChargeMenuMap) {

        // QuickCIS※電力契約レコードタイプマップ
        Map<String, String> cntrRtMap = qcisRecordTypeMap.get('dcis2__Contract__c');

        // 作成・更新用QuickCIS※電力契約マップ  Map<突合用契約商品ID, Map<項目名, 設定値>>
        Map<String, Map<String, String>> upsQcisCntrMap = new Map<String, Map<String, String>>();
        // 突合用契約商品IDリスト  QuickCIS契約番号または※ARVE契約番号（Name）を保持
        List<String> cntrIdList = new List<String>();
        // 再取得※電力契約マップ  Map<Id, ※電力契約>
        Map<String, CMN_QuickCISRecord> latestQcisCntrMap = new Map<String, CMN_QuickCISRecord>();

        // 処理対象を分割元契約商品ごとにマップに格納
        Map<Id, Set<CMN_ContractItem__c>> sourceOutcomeMap = new Map<Id, Set<CMN_ContractItem__c>>(); // 分割元契約商品-分割先契約商品マップ  Map<分割元契約商品.Id, Set<分割先契約商品>>
        for (Id id: tgtMap.keySet()) {
            CMN_ContractItem__c ci = tgtMap.get(id);
            if (sourceOutcomeMap.containsKey(ci.CMN_DivisionSource__c)) {
                sourceOutcomeMap.get(ci.CMN_DivisionSource__c).add(ci);
            } else {
                sourceOutcomeMap.put(ci.CMN_DivisionSource__c, new Set<CMN_ContractItem__c>{ci});
            }
        }

        // 支払情報（最新履歴）マップ
        Map<Id,CMN_PaymentInfo__c> pilhMap = getPayInfoLastHistoryMap(tgtMap);
        
        // 分割元ごとの連番値取得
        Map<Id, Decimal> divSeqNumMap = getDivisionSeqNum(sourceOutcomeMap.keySet());

        // 分割元ごとに処理
        for (Id divSourceCiId: sourceOutcomeMap.keySet()) {
            // 処理対象分割先契約商品
            Set<CMN_ContractItem__c> outcomeSet = sourceOutcomeMap.get(divSourceCiId);
            // 連番値
            Decimal divSeqNum = divSeqNumMap.get(divSourceCiId);
            
            // マッピングデータを生成
            for(CMN_ContractItem__c ci : outcomeSet) {
                // 突合用のキー値にQuickCIS契約番号を格納
                String cntrId = ci.CMN_QCISContractId__c;
                // QuickCIS契約番号がnullか継続利用対象の複製契約の場合は契約番号（Name）を格納
                if (ci.CMN_QCISContractId__c == null || (ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C)) {
                    cntrId = ci.Name;
                }

                // 合算請求マスタ更新区分 が "加入" 又は "脱退→加入" かつ　支払情報.合算請求ID が null の場合、連携対象外とする
                if((ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '加入' ||  ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入')
                   && String.isBlank(ci.CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c)){
                    ci.CMN_LinkSts__c = LINKSTS_ERR;
                    ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_SUMINVOICEID;
                // 合算請求マスタ更新区分 が "脱退→新規" 又は "脱退→加入" かつ　支払情報(最新履歴レコード).請求方式 が取得できない場合、連携対象外とする
                }else if((ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→新規' ||  ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入')
                   && (!pilhMap.containsKey(ci.Id) || String.isBlank(pilhMap.get(ci.Id).CMN_InvoiceMethod__c))){
                    ci.CMN_LinkSts__c = LINKSTS_ERR;
                    ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_INVOICEMETHOD;
                // 連携対象の場合
                }else{
                    // 電力契約を新規作成する場合は連番を+1する
                    if (ci.CMN_LinkageKbn__c == LINKAGEKBN_C) {
                        divSeqNum = divSeqNum != null ? divSeqNum + 1 : 1;
                    }
                    // 作成・更新用マッピングデータを生成
                    Map<String, String> mapping = mappingContractDivision(ci, cntrRtMap, qcisAccMap, qcisCntrMap, qcisChargeMenuMap, divSeqNum, pilhMap.get(ci.Id));
                    // 作成・更新用マップに格納
                    upsQcisCntrMap.put(cntrId, mapping);
                }
            }
            // 連番値を最新化
            divSeqNumMap.put(divSourceCiId, divSeqNum);
        }

        // APIリクエスト（QuickCIS※電力契約の作成・更新）
        String errMsg;
        if(!upsQcisCntrMap.isEmpty()) {
            // 作成・更新用JSONリスト（1件ごとの更新内容を保持）
            List<String> jsonList = new List<String>();

            // 1件ずつJSON文字列に変換
            for(String cntrId : upsQcisCntrMap.keySet()) {
                Map<String, String> mapping = upsQcisCntrMap.get(cntrId);
                String json = '{"attributes":{"type":"dcis2__Contract__c"}';
                for(String fieldName : mapping.keySet()) {
                    json += ',"' + fieldName + '":' + mapping.get(fieldName);
                }
                // 作成・更新用JSONリストに追加
                jsonList.add(json);
                // 突合用契約商品IDリストに追加
                cntrIdList.add(cntrId);
            }
            
            // JSONを1つの文字列にマージ
            String jsonBody = '{"allOrNone":false,"records":[' + String.join(jsonList, '},') + '}]}';
            // リクエスト結果マップ
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();
            // 再取得用IDセット
            Set<String> latestQcisCntrIdSet = new Set<String>();

            // リクエスト送信
            try {
                HttpResponse patchRes;
                // Apexテスト実行時、モックデータを返す
                if(Test.isRunningTest()) {
                    String pattern = this.resPattern.contains('upsertQcisContract') ? this.resPattern.split('_')[1] : 'upsertQcisContract';
                    patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, jsonList.size()).respond(new HTTPRequest());

                // APIリクエスト送信
                }else {
                    patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody, 'dcis2__Contract__c', 'Id');
                }

                // リクエスト結果をレコード単位でマップに格納
                if(patchRes.getStatusCode() == 200) {
                    List<QCIS_APIRes> patchResList = (List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class);
                    for(Integer i = 0; i < cntrIdList.size(); i ++) {
                        resultMap.put(cntrIdList[i], patchResList[i]);
                        latestQcisCntrIdSet.add(patchResList[i].id);
                        // Apexテスト実行時、再取得※電力契約マップにモックデータを格納
                        if(Test.isRunningTest()) {
                            CMN_QuickCISRecord rec = new CMN_QuickCISRecord();
                            rec.Name = 'CI-25-01-0000' + String.valueOf(i).leftPad(3, '0');
                            if(this.resPattern == 'failedGetLatestQcisCntrMap') {
                                latestQcisCntrMap = null;
                            }else {
                                if(this.resPattern == 'contractItemIllegalError') {
                                    rec.Name = rec.Name.rightPad(1000, '0');
                                }
                                latestQcisCntrMap.put(patchResList[i].id, rec);
                            }
                        }
                    }
                }else {
                    errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                }
            }catch(Exception e) {
                errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
            }

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // 作成・更新した※電力契約の再取得
                
                // 再取得用IDセットからnullを除外
                latestQcisCntrIdSet.remove(null);
                // ※電力契約を再取得
                if(!latestQcisCntrIdSet.isEmpty()) {
                    if(!Test.isRunningTest()) {
                        latestQcisCntrMap = getQcisContract(accessToken, qcisRecordTypeMap, latestQcisCntrIdSet, 'Id');
                    }
                }
                // 再取得に失敗した場合はエラー終了
                if(latestQcisCntrMap == null) {
                    errMsg = 'QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + ERRMSG002;
                    return errMsg;
                }

                // リクエスト結果が成功の場合、ARVE契約商品にQuickCIS契約番号を反映
                // リクエスト結果がエラーの場合、ARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // マップからリクエスト結果を取り出す
                    // 突合用のキー値にQuickCIS契約番号を格納
                    String cntrId = ci.CMN_QCISContractId__c;
                    // QuickCIS契約番号がnullか継続利用対象の複製契約の場合は契約番号（Name）を格納
                    if (ci.CMN_QCISContractId__c == null || (ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C)) {
                        cntrId = ci.Name;
                    }
                    QCIS_APIRes result = resultMap.get(cntrId);

                    // エラー発生の場合、連携エラーにする
                    if(result != null && !result.errors.isEmpty()) {
                        ci.CMN_LinkSts__c = LINKSTS_ERR;
                        ci.CMN_LinkErrorDetail__c = ('QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + result.errors).left(255);

                    // 正常終了の場合、ARVE契約商品へQuickCIS契約番号のバックおよび
                    // 作成したレコードをQuickCIS※電力契約マップに追加
                    }else {
                        // 連携エラーでない場合
                        if(ci.CMN_LinkSts__c != LINKSTS_ERR){
                            // 再取得した※電力契約を取り出す
                            CMN_QuickCISRecord latestQcisCntr = latestQcisCntrMap.get(result.Id);
                            if(latestQcisCntr != null) {
                                // QuickCIS契約番号の継続利用対象の複製契約以外の場合、QuickCIS契約番号を設定・更新
                                if(!(ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C)){
                                    // //ARVE契約商品.QuickCIS契約番号
                                    ci.CMN_QCISContractId__c = latestQcisCntr.Name;
                                } else {                                    
                                    // 複製の契約商品を作成した時点で、初めから元の契約番号をQuickCIS契約番号に設定
                                    ci.CMN_ReproducedQCISContractId__c = latestQcisCntr.Name;
                                   
                                }
                                // 作成・更新した※電力契約をQuickCIS※電力契約マップに追加
                                qcisCntrMap.put(latestQcisCntr.Name, latestQcisCntr);
                            }
                        }
                    }
                }
            }
        }
        
        // 分割元契約商品を連番値の最新の値で更新
        updateDivisionSeqNum(divSeqNumMap);
        
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS※電力契約' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * QuickCIS設定料金アイテム（需要家別）マスタ（親）の作成
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @param qcisChargeMenuMap QuickCIS※料金メニューマップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String insertAccountChargeItemMaster(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, CMN_QuickCISRecord> qcisCntrMap, Map<String, String> qcisChargeMenuMap) {

        // 作成用QuickCIS設定料金アイテム（需要家別）マスタリスト
        // Map<QuickCIS契約番号, 料金メニュー名, Map<項目名, 設定値>>
        Map<String, Map<String, Map<String, String>>> insQcisAcctCiMstMap =
            new Map<String, Map<String, Map<String, String>>>();

        // マッピングデータを生成
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // QuickCIS契約番号
            String qcisCntrId = '';
            if (ci.CMN_LinkageKbn__c == LINKAGEKBN_C && ci.CMN_ContinuedUseFlg__c) {
                // 複製追加の場合、QuickCIS契約番号（複製後）に対応する電力契約に紐づけ
                qcisCntrId = ci.CMN_ReproducedQCISContractId__c;
            } else {
                // QuickCIS契約番号に対応する電力契約に紐づけ
                qcisCntrId = ci.CMN_QCISContractId__c;
            }
            // 契約商品.連携処理区分が"Create"以外または契約商品.個別単価フラグがFALSEの場合は処理をスキップ
            if(ci.CMN_LinkageKbn__c != LINKAGEKBN_C || !ci.CMN_IndividualUnitPriceFlg__c) {
                continue;
            }
            // 作成用マッピングデータを生成  Map<精査対象項目名（料金アイテム）, Map<項目名, 値>>
            Map<String, Map<String, String>> mapping = mappingAcctCiMst(ci, qcisCntrMap.get(qcisCntrId), qcisChargeMenuMap);
            insQcisAcctCiMstMap.put(qcisCntrId, mapping);
        }

        // APIリクエスト（QuickCIS設定料金アイテム（需要家別）マスタの作成）
        String errMsg;
        if(!insQcisAcctCiMstMap.isEmpty()) {
            // 作成・更新用JSONリスト（200件ごとの更新内容を保持）
            List<List<String>> wholeJsonList = new List<List<String>>();
            // リクエスト結果の突合用キーリスト
            List<String> keyList = new List<String>();
            // リクエスト結果の突合用キーマップ  Map<QuickCIS契約番号, List<料金メニュー名>>
            Map<String, List<String>> keyMap = new Map<String, List<String>>();
            
            // 作成対象の契約商品単位でのループ処理
            List<String> jsonList = new List<String>();
            for(String qcisCntrId : insQcisAcctCiMstMap.keySet()) {
                // リクエスト結果の突合用キーリスト・マップにQuickCIS契約番号を追加
                keyList.add(qcisCntrId);
                keyMap.put(qcisCntrId, new List<String>());
                // 作成用QuickCIS設定料金アイテム（需要家別）マスタマップから対象の※電力契約分のデータを取得
                Map<String, Map<String, String>> chargeMenuMap = insQcisAcctCiMstMap.get(qcisCntrId);
                // 設定料金アイテム単位でのループ処理
                for(String chargeMenuFieldName : chargeMenuMap.keySet()) {
                    // リクエスト結果の突合用キーマップに付帯メニュー・窓情報を追加
                    keyMap.get(qcisCntrId).add(chargeMenuFieldName);
                    // 1件ずつJSON文字列に変換
                    Map<String, String> mapping = chargeMenuMap.get(chargeMenuFieldName);
                    String referenceId = qcisCntrId + chargeMenuFieldName;
                    String json = '{"attributes":{"type":"C_AccountChargeItemMaster__c","referenceId":"' + referenceId + '"}';
                    for(String fieldName : mapping.keySet()) {
                        json += ',"' + fieldName + '":' + mapping.get(fieldName);
                    }
                    // 200件に到達した場合、作成・更新用JSONリストに追加
                    if(jsonList.size() == 200) {
                        wholeJsonList.add(jsonList.clone());
                        jsonList.clear();
                    }
                    jsonList.add(json);
                }
            }
            // 残りの分も作成・更新用JSONリストに追加
            if(!jsonList.isEmpty()) {
                wholeJsonList.add(jsonList);
            }
            
            // 200件ずつリクエスト送信
            List<QCIS_APIRes> postResList = new List<QCIS_APIRes>();
            for(List<String> json200List : wholeJsonList) {
                String jsonBody = '{"records":[' + String.join(json200List, '},') + '}]}';
                // リクエスト送信
                try {
                    HttpResponse postRes;
                    // Apexテスト実行時、モックデータを返す
                    if(Test.isRunningTest()) {
                        String pattern = this.resPattern.contains('insertAccountChargeItemMaster') ? this.resPattern.split('_')[1] : 'insertAccountChargeItemMaster';
                        postRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, json200List.size()).respond(new HTTPRequest());

                    // APIリクエスト送信
                    }else {
                        postRes = APIRequest.sendPostRequest(accessToken, jsonBody);
                    }

                    // リクエスト結果をレコード単位でリストに格納
                    if(postRes.getStatusCode() == 200) {
                        postResList.addAll((List<QCIS_APIRes>)JSON.deserialize(postRes.getBody(), List<QCIS_APIRes>.class));
                    }else {
                        errMsg = 'ステータスコード' + postRes.getStatusCode() ;
                    }
                }catch(Exception e) {
                    errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
                }
            }
            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // リクエスト結果格納用マップ  Map<QuickCIS契約番号, Map<料金メニュー名, レコード作成結果>>
                Map<String, Map<String, QCIS_APIRes>> resultRecMap = new Map<String, Map<String, QCIS_APIRes>>();
                // マッピング置換用マップ
                Map<String, String> valPatternAmowInfoName = this.mapValPattern.get('mappingAcctCiMst').get('amowInfoName');

                // リクエスト結果を突合用マップに格納
                Integer i = 0;
                for(String qcisCntrId : keyList) {
                    resultRecMap.put(qcisCntrId, new Map<String, QCIS_APIRes>());
                    for(String fieldName : keyMap.get(qcisCntrId)) {
                        // 付帯メニュー・窓情報                        
                        String amowInfoName = insQcisAcctCiMstMap.get(qcisCntrId).get(fieldName).get('C_AdditionalMenuOrWindowInformation__c');
                        resultRecMap.get(qcisCntrId).put(amowInfoName, postResList[i]);
                        i ++;
                    }
                }
                
                // リクエスト結果が成功の場合は契約商品にIDを連携し、エラーの場合はARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // QuickCIS契約番号
                    String qcisCntrId = '';
                    if (ci.CMN_LinkageKbn__c == LINKAGEKBN_C && ci.CMN_ContinuedUseFlg__c) {
                        // 複製追加の場合、QuickCIS契約番号（複製後）に対応する電力契約に紐づけ
                        qcisCntrId = ci.CMN_ReproducedQCISContractId__c;
                    } else {
                        // QuickCIS契約番号に対応する電力契約に紐づけ
                        qcisCntrId = ci.CMN_QCISContractId__c;
                    }
                    // マップからリクエスト結果を取り出す
                    Map<String, QCIS_APIRes> result = resultRecMap.get(qcisCntrId);
                    // 契約商品.設定料金アイテム（需要家別）情報の値をリセット
                    ci.CMN_AccountChargeItemMasterInfo__c = '';
                    // リクエスト結果を取り出せなかった場合は処理対象外のため、ここで終了
                    if(result == null) {
                        continue;
                    }
                    // 基本単価ID
                    String basicUnitPriceId = '';
                    // レコード（付帯メニュー・窓情報）単位に結果を確認
                    for(String amowInfoName : valPatternAmowInfoName.keySet()) {
                        QCIS_APIRes resultRec = result.get('"' + amowInfoName + '"');

                        // エラー発生の場合、連携エラーにする
                        if(resultRec != null && !resultRec.errors.isEmpty()) {
                            ci.CMN_LinkSts__c = LINKSTS_ERR;
                            ci.CMN_LinkErrorDetail__c = ('QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + resultRec.errors).left(255);

                        // 作成に成功した場合、契約商品.設定料金アイテム（需要家別）情報にレコードIDを設定
                        }else {
                            // 付帯メニュー・窓情報名
                            String amowInfoLabel = valPatternAmowInfoName.get(amowInfoName);
                            // 付帯メニュー・窓情報ID
                            String resultRecId = resultRec?.id ?? '';
                            // 基本単価は'W002'で契約商品.設定料金アイテム（需要家別）情報に値を設定
                            if(amowInfoName == 'W001') {
                                basicUnitPriceId = resultRecId;
                            }else {
                                if(amowInfoName == 'W002') {
                                    resultRecId = basicUnitPriceId == '' ? resultRecId : basicUnitPriceId;
                                }
                                ci.CMN_AccountChargeItemMasterInfo__c += amowInfoLabel + '①：' + resultRecId + '\n';
                                ci.CMN_AccountChargeItemMasterInfo__c += amowInfoLabel + '②：' + '\n';
                                ci.CMN_AccountChargeItemMasterInfo__c += amowInfoLabel + '③：' + '\n';
                            }
                        }
                    }
                    // 連携エラーの場合、設定料金アイテム（需要家別）情報を空白に設定
                    if(ci.CMN_LinkSts__c == LINKSTS_ERR) {
                        ci.CMN_AccountChargeItemMasterInfo__c = '';
                    }
                }
            }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * QuickCIS設定料金アイテム（需要家別）マスタ（子）の作成・更新・削除
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String upsertAccountChargeItemMasterChild(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, CMN_QuickCISRecord> qcisCntrMap) {

        // 作成用QuickCIS設定料金アイテム（需要家別）マスタリスト
        // Map<契約商品ID, Map<作成パターン, Map<項目名, 設定値>>>
        Map<String, Map<String, Map<String, String>>> upsQcisAcctCiMstMap =
            new Map<String, Map<String, Map<String, String>>>();
        // 契約商品IDと※電力契約（親）のIDマップ
        Map<String, String> qcisCntrIdMap = new Map<String, String>();
        // QuickCIS設定料金マスタ（需要家別）のIDとARVE契約商品のマップ
        Map<String, String> delMasterInfoMap = new Map<String, String>();
        // QuickCIS設定料金マスタ（需要家別）のIDとARVE契約商品IDのマップ
        Map<String, String> masterInfo_cIdMap = new Map<String, String>();
        // QuickCIS設定料金マスタ（需要家別）のIDとARVE契約商品IDのマップ
        Set<String> masterInfoIdSet = new Set<String>();
        // 契約商品から取り出した設定料金アイテム（需要家別）情報格納リスト
        List<String> masterInfoList = new List<String>();
        // 除外対象契約商品IDセット
        Set<String> excludeCtrIdSet = new Set<String>();

        // 設定料金アイテム需要家別マスタ取得処理
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // 設定料金アイテム（需要家別）情報取り出し
            if(!String.isBlank(ci.CMN_AccountChargeItemMasterInfo__c)) {
                masterInfoList = ci.CMN_AccountChargeItemMasterInfo__c.replace('\r\n', '\n').replace('\r', '\n').split('\n');
                for(String masterInfo : masterInfoList) {
                    String masterInfoRec = masterInfo.substringAfter('：');
                    if(!String.isBlank(masterInfoRec)) {
                        masterInfo_cIdMap.put(masterInfoRec, ci.Id);
                        masterInfoIdSet.add(masterInfoRec);
                    }
                }
            }
        }

        Map<String, CMN_QuickCISRecord> qcisMap = getQcisAccountChargeItemMaster(accessToken, masterInfoIdSet);
        
        // 設定料金アイテム需要家別マスタ取得結果検査
        for(String masterInfoId : masterInfoIdSet) {
            // 設定料金アイテムが取得出来なかった場合は除外対象契約商品IDセットに格納する
            if(!qcisMap.containsKey(masterInfoId)) {
                excludeCtrIdSet.add(masterInfo_cIdMap.get(masterInfoId));
            }
        }

        // マッピングデータを生成
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // 除外対象契約商品IDセットに格納されている場合は連携エラーとする
            if(excludeCtrIdSet.contains(ci.Id)) {
                ci.CMN_LinkSts__c = LINKSTS_ERR;
                ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_NOQCISACCMSTITEM;
                continue;
            } else {
                // 紐づけ元契約商品.QuickCIS契約番号
                String qcisCntrParentId = ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c;
                // ※電力契約（親）
                // ・※電力契約（親）の取得失敗時は前処理でエラーとなるため、
                // 　※電力契約（親）の取得が成功する前提で処理を実装している
                CMN_QuickCISRecord qcisCntrParent = qcisCntrMap.get(qcisCntrParentId);
                // 契約商品IDと※電力契約（親）のマッピングを作成
                qcisCntrIdMap.put(ci.Id, qcisCntrParent.Id);

                // 2026/02/19 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update Start
                // 作成用マッピングデータを生成  Map<作成パターン, Map<項目名, 値>>
                //Map<String, Map<String, String>> mapping = mappingAcctCiMstChild(ci, qcisCntrParent, delMasterInfoMap, masterInfoList);                
                Map<String, Map<String, String>> mapping = mappingAcctCiMstChild(ci, qcisCntrMap, delMasterInfoMap, masterInfoList);
                // 2026/02/19 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update End
                // 作成用QuickCIS設定料金アイテム（需要家別）マスタマップに格納
                if(!mapping.isEmpty()) {
                    upsQcisAcctCiMstMap.put(ci.Id, mapping);
                }
            }
        }

        // 削除処理
        String errMsg;
        if(!delMasterInfoMap.isEmpty()) {
            errMsg = deleteAccountChargeItemMasterChild(tgtMap, delMasterInfoMap, accessToken, upsQcisAcctCiMstMap);
        }

        if(String.isBlank(errMsg)) {
            // APIリクエスト（QuickCIS設定料金アイテム（需要家別）マスタの作成・更新）
        if(!upsQcisAcctCiMstMap.isEmpty()) {
            // 作成・更新用JSONリスト（200件ごとの更新内容を保持）
            List<List<String>> wholeJsonList = new List<List<String>>();
            // リクエスト結果の突合用キーリスト  契約商品ID
            List<String> keyList = new List<String>();
            // リクエスト結果の突合用キーマップ  Map<契約商品ID, List<作成パターン>>
            Map<String, List<String>> keyMap = new Map<String, List<String>>();
            
            // 契約商品単位でのループ処理
            List<String> jsonList = new List<String>();
            for(String cntrId : upsQcisAcctCiMstMap.keySet()) {
                // リクエスト結果の突合用キーリスト・マップに契約商品IDを追加
                keyList.add(cntrId);
                keyMap.put(cntrId, new List<String>());
                // 作成用QuickCIS設定料金アイテム（需要家別）マスタマップから対象の契約商品分のデータを取得
                Map<String, Map<String, String>> chargeMenu = upsQcisAcctCiMstMap.get(cntrId);
                // 作成パターン単位でのループ処理
                for(String createPttrn : chargeMenu.keySet()) {
                    // リクエスト結果の突合用キーマップに作成パターンを追加
                    keyMap.get(cntrId).add(createPttrn);
                    // 1件ずつJSON文字列に変換
                    Map<String, String> mapping = chargeMenu.get(createPttrn);
                    String referenceId = cntrId + createPttrn;
                    String json = '{"attributes":{"type":"C_AccountChargeItemMaster__c","referenceId":"' + referenceId + '"}';
                    for(String fieldName : mapping.keySet()) {
                        json += ',"' + fieldName + '":' + mapping.get(fieldName);
                    }
                    // 200件に到達した場合、作成・更新用JSONリストに追加
                    if(jsonList.size() == 200) {
                        wholeJsonList.add(jsonList.clone());
                        jsonList.clear();
                    }
                    jsonList.add(json);
                }
            }
            // 残りの分も作成・更新用JSONリストに追加
            if(!jsonList.isEmpty()) {
                wholeJsonList.add(jsonList);
            }
            
            // 200件ずつリクエスト送信
            List<QCIS_APIRes> patchResList = new List<QCIS_APIRes>();

            for(List<String> json200List : wholeJsonList) {
                String jsonBody = '{"records":[' + String.join(json200List, '},') + '}]}';

                // リクエスト送信
                try {
                    HttpResponse patchRes;
                    // Apexテスト実行時、モックデータを返す
                    if(Test.isRunningTest()) {
                        String pattern = this.resPattern.contains('upsertAcctChargeItemMasterChild') ? this.resPattern.split('_')[1] : 'upsertAcctChargeItemMasterChild';
                        patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, json200List.size()).respond(new HTTPRequest());

                    // APIリクエスト送信
                    }else {
                        patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody, 'C_AccountChargeItemMaster__c', 'Id');
                    }

                    // リクエスト結果をレコード単位でリストに格納
                    if(patchRes.getStatusCode() == 200) {
                        patchResList.addAll((List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class));
                    }else {
                        errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                    }
                }catch(Exception e) {
                    errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
                }
            }

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // リクエスト結果格納用マップ  Map<契約商品ID, Map<作成パターン, レコード作成結果>>
                Map<String, Map<String, QCIS_APIRes>> resultRecMap = new Map<String, Map<String, QCIS_APIRes>>();
                
                // ※電力契約（親）更新用リスト
                Set<String> updQcisCntrIdList = new Set<String>();
                // 作成パターン名称マップ
                Map<String, String> createPttrnMap = this.mapValPattern.get('mappingAcctCiMstChild').get('createPttrn');

                // リクエスト結果を突合用マップに格納
                Integer i = 0;
                for(String cntrId : keyList) {
                    resultRecMap.put(cntrId, new Map<String, QCIS_APIRes>());
                    for(String createPttrn : keyMap.get(cntrId)) {
                        // 付帯メニュー・窓情報
                        resultRecMap.get(cntrId).put(createPttrn, patchResList[i]);
                        i ++;
                    }
                }

                // リクエスト結果が成功の場合は契約商品にIDを連携し、エラーの場合はARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // マップからリクエスト結果を取り出す
                    Map<String, QCIS_APIRes> result = resultRecMap.get(ci.Id);
                    // 契約商品.設定料金アイテム（需要家別）情報の元の値を保持
                    String originalAccChargeItemMasterInfo = ci.CMN_AccountChargeItemMasterInfo__c;
                    // 契約商品.設定料金アイテム（需要家別）情報の初期化
                    ci.CMN_AccountChargeItemMasterInfo__c = '';
                    // リクエスト結果を取り出せなかった場合は処理対象外のため、ここで終了
                    if(result == null) {
                        continue;
                    }
                    // 作成パターン単位に結果を確認
                    for(String createPttrn : createPttrnMap.keySet()) {
                        QCIS_APIRes resultRec = result.get(createPttrn);

                        // エラー発生の場合、連携エラーにする
                        if(resultRec != null && !resultRec.errors.isEmpty()) {
                            ci.CMN_LinkSts__c = LINKSTS_ERR;
                            // result.errorsが文字列認識されなかったため、Stringと連結させ文字列化する。
                            String errors = '' + resultRec.errors;
                            if(errors.contains('エンティティは削除済みです')) {
                                ci.CMN_LinkErrorDetail__c = 'QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + LINKERRORDETAIL_NOQCISACCMSTITEM;
                            } else {
                                ci.CMN_LinkErrorDetail__c = ('QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + resultRec.errors).left(255);
                            }
                            continue;

                        // 作成に成功した場合、契約商品.設定料金アイテム（需要家別）情報にレコードIDを設定
                        }else {
                            String createPttrnLabel = createPttrnMap.get(createPttrn);
                            String resultRecId = resultRec?.id ?? '';
                            ci.CMN_AccountChargeItemMasterInfo__c += createPttrnLabel + '①：' + resultRecId + '\n';
                            ci.CMN_AccountChargeItemMasterInfo__c += createPttrnLabel + '②：' + '\n';
                            ci.CMN_AccountChargeItemMasterInfo__c += createPttrnLabel + '③：' + '\n';
                        }
                    }
                    // 連携エラーの場合、設定料金アイテム（需要家別）情報を元の値に設定
                    if(ci.CMN_LinkSts__c == LINKSTS_ERR) {
                        ci.CMN_AccountChargeItemMasterInfo__c = originalAccChargeItemMasterInfo;
                    } else {
                        //作成に成功した場合、契約商品IDから※電力契約（親）のIDを更新用リストに格納する
                        updQcisCntrIdList.add(qcisCntrIdMap.get(ci.Id));
                    }
                    // Apexテスト実行時かつARVE契約商品更新エラーパターンの場合、更新が失敗する値を設定する
                    if(Test.isRunningTest()) {
                        if(this.resPattern == 'contractItemIllegalError') {
                            ci.CMN_Product2__c = '01tXX000000XXXXXXX';
                        }
                    }
                    //※電力契約（親）の登録ステータスを"仮登録"に変更する
                    errMsg = updateQcisContractChildStatus(tgtMap,updQcisCntrIdList, qcisCntrIdMap, accessToken);
                }
            }
        }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }

    /**
     * QuickCIS設定料金アイテム（需要家別）マスタ（子）の削除
     * 子契約処理にて使用。
     * @param tgtMap ARVE契約商品マップ
     * @param delMasterInfoMap 削除対象の設定料金アイテム（需要家別）IDとARVE契約商品のマッピング
     * @param accessToken アクセストークン
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String deleteAccountChargeItemMasterChild(Map<Id, CMN_ContractItem__c> tgtMap, Map<String, String> delMasterInfoMap, 
            String accessToken, Map<String, Map<String, Map<String, String>>> upsQcisAcctCiMstMap) {
        // 作成・更新用JSONリスト（200件ごとの更新内容を保持）
        List<List<String>> wholeJsonList = new List<List<String>>();
        // 更新用JSONリスト（1件ごとの更新内容を保持）
        List<String> jsonList = new List<String>();
        
        String errMsg;

        // 作成用マッピングデータを生成
        if(!delMasterInfoMap.isEmpty()) {
            for(String delMasterInfoId : delMasterInfoMap.keySet()) {
                if(jsonList.size() == 200) {
                    wholeJsonList.add(jsonList.clone());
                    jsonList.clear();
                }
                jsonList.add(delMasterInfoId);
            }
            // 残りの分も作成・更新用JSONリストに追加
            if(!jsonList.isEmpty()) {
                wholeJsonList.add(jsonList);
            }

             // 200件ずつリクエスト送信
            List<QCIS_APIRes> deleteResList = new List<QCIS_APIRes>();
            // リクエスト結果マップ  Map<設定料金アイテム（需要家別）マスタID, リクエスト結果>
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();

            // APIリクエスト（QuickCIS設定料金アイテム（需要家別）マスタの削除）
            for(List<String> json200List : wholeJsonList){
                // JSONを1つの文字列にマージ
                String jsonBody = String.join(json200List, ',');
                // リクエスト送信
                try {
                    HttpResponse deleteRes;
                    // Apexテスト実行時、モックデータを返す
                    if(Test.isRunningTest()) {
                        String pattern = this.resPattern.contains('deleteAcctChargeItemMasterChild') ? this.resPattern.split('_')[1] : 'deleteAcctChargeItemMasterChild';
                        deleteRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, json200List.size()).respond(new HTTPRequest());

                    // APIリクエスト送信
                    }else {
                        deleteRes = APIRequest.sendDeleteRequest(accessToken, jsonBody);
                    }

                    // リクエスト結果をレコード単位でマップに格納
                    if(deleteRes.getStatusCode() == 200) {
                        deleteResList.addAll((List<QCIS_APIRes>)JSON.deserialize(deleteRes.getBody(), List<QCIS_APIRes>.class));
                        for(QCIS_APIRes deleteResRec : deleteResList) {
                            resultMap.put(deleteResRec.Id, deleteResRec);
                        }
                    }else {
                        errMsg = 'ステータスコード' + deleteRes.getStatusCode() ;
                    }
                }catch(Exception e) {
                    errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
                }
            }
            

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                for(String masterInfoId : resultMap.keySet()) {
                    QCIS_APIRes result = resultMap.get(masterInfoId);
                    // エラー発生の場合、連携エラーにする
                    if(result != null && !result.errors.isEmpty()) {
                        String cId = delMasterInfoMap.get(result.Id);
                        // 作成・更新用設定料金アイテム（需要家別）マスタマップから除外する
                        if(upsQcisAcctCiMstMap.containsKey(cId)) {
                            upsQcisAcctCiMstMap.remove(cId);
                        }
                        tgtMap.get(cId).CMN_LinkSts__c = LINKSTS_ERR;
                        // エンティティ削除済みであればレコードIDを記載する
                        // result.errorsが文字列認識されなかったため、Stringと連結させ文字列化する。
                        String errors = '' + result.errors;
                        if(errors.contains('エンティティは削除済みです')) {
                            String errorDetail = tgtMap.get(cId).CMN_LinkErrorDetail__c == null ? '' : tgtMap.get(cId).CMN_LinkErrorDetail__c;
                            if(errorDetail.contains(LINKERRORDETAIL_NOQCISACCMSTITEM)) {
                                tgtMap.get(cId).CMN_LinkErrorDetail__c += ',' + result?.Id;
                            } else {
                                tgtMap.get(cId).CMN_LinkErrorDetail__c = 'QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_DELETE_FAILED + '：' + LINKERRORDETAIL_NOQCISACCMSTITEM + result?.Id;
                            }
                        } else {
                            tgtMap.get(cId).CMN_LinkErrorDetail__c = ('QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_DELETE_FAILED + '：' + result.errors).left(255);
                        }
                    }
                }
            }
        }

        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS設定料金アイテム（需要家別）マスタ削除' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }

    /**
     * QuickCIS設定料金アイテム（需要家別）マスタ（子）の作成
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String insertAccountChargeItemMasterChild(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, CMN_QuickCISRecord> qcisCntrMap) {

        // 作成用QuickCIS設定料金アイテム（需要家別）マスタリスト
        // Map<契約商品ID, Map<作成パターン, Map<項目名, 設定値>>>
        Map<String, Map<String, Map<String, String>>> insQcisAcctCiMstMap =
            new Map<String, Map<String, Map<String, String>>>();

        // QuickCIS設定料金マスタ（需要家別）のIDとARVE契約商品のマップ
        Map<String, String> delMasterInfoMap = new Map<String, String>();
        // 契約商品から取り出した設定料金アイテム（需要家別）情報格納リスト
        List<String> masterInfoList = new List<String>();

        // マッピングデータを生成
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // 契約商品.連携処理区分が"Create"以外の場合は処理をスキップ（ARVE-5331）
            if(ci.CMN_LinkageKbn__c != LINKAGEKBN_C) {
                continue;
            }
            // 紐づけ元契約商品.QuickCIS契約番号
            String qcisCntrParentId = ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c;
            // ※電力契約（親）
            // ・※電力契約（親）の取得失敗時は前処理でエラーとなるため、
            // 　※電力契約（親）の取得が成功する前提で処理を実装している
            CMN_QuickCISRecord qcisCntrParent = qcisCntrMap.get(qcisCntrParentId);
            // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update Start
            // 作成用マッピングデータを生成  Map<作成パターン, Map<項目名, 値>>
            //Map<String, Map<String, String>> mapping = mappingAcctCiMstChild(ci, qcisCntrParent, delMasterInfoMap, masterInfoList);

            Map<String, Map<String, String>> mapping = mappingAcctCiMstChild(ci, qcisCntrMap, delMasterInfoMap, masterInfoList);
            // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update End

            // 作成用QuickCIS設定料金アイテム（需要家別）マスタマップに格納
            if(!mapping.isEmpty()) {
                insQcisAcctCiMstMap.put(ci.Id, mapping);
            }
        }

        // APIリクエスト（QuickCIS設定料金アイテム（需要家別）マスタの作成）
        String errMsg;
        if(!insQcisAcctCiMstMap.isEmpty()) {
            // 作成・更新用JSONリスト（200件ごとの更新内容を保持）
            List<List<String>> wholeJsonList = new List<List<String>>();
            // リクエスト結果の突合用キーリスト  契約商品ID
            List<String> keyList = new List<String>();
            // リクエスト結果の突合用キーマップ  Map<契約商品ID, List<作成パターン>>
            Map<String, List<String>> keyMap = new Map<String, List<String>>();
            
            // 契約商品単位でのループ処理
            List<String> jsonList = new List<String>();
            for(String cntrId : insQcisAcctCiMstMap.keySet()) {
                // リクエスト結果の突合用キーリスト・マップに契約商品IDを追加
                keyList.add(cntrId);
                keyMap.put(cntrId, new List<String>());
                // 作成用QuickCIS設定料金アイテム（需要家別）マスタマップから対象の契約商品分のデータを取得
                Map<String, Map<String, String>> chargeMenu = insQcisAcctCiMstMap.get(cntrId);
                // 作成パターン単位でのループ処理
                for(String createPttrn : chargeMenu.keySet()) {
                    // リクエスト結果の突合用キーマップに作成パターンを追加
                    keyMap.get(cntrId).add(createPttrn);
                    // 1件ずつJSON文字列に変換
                    Map<String, String> mapping = chargeMenu.get(createPttrn);
                    String referenceId = cntrId + createPttrn;
                    String json = '{"attributes":{"type":"C_AccountChargeItemMaster__c","referenceId":"' + referenceId + '"}';
                    for(String fieldName : mapping.keySet()) {
                        json += ',"' + fieldName + '":' + mapping.get(fieldName);
                    }
                    // 200件に到達した場合、作成・更新用JSONリストに追加
                    if(jsonList.size() == 200) {
                        wholeJsonList.add(jsonList.clone());
                        jsonList.clear();
                    }
                    jsonList.add(json);
                }
            }
            // 残りの分も作成・更新用JSONリストに追加
            if(!jsonList.isEmpty()) {
                wholeJsonList.add(jsonList);
            }
            
            // 200件ずつリクエスト送信
            List<QCIS_APIRes> patchResList = new List<QCIS_APIRes>();

            for(List<String> json200List : wholeJsonList) {
                String jsonBody = '{"records":[' + String.join(json200List, '},') + '}]}';

                // リクエスト送信
                try {
                    HttpResponse patchRes;
                    // Apexテスト実行時、モックデータを返す
                    if(Test.isRunningTest()) {
                        String pattern = this.resPattern.contains('insertAcctChargeItemMasterChild') ? this.resPattern.split('_')[1] : 'insertAcctChargeItemMasterChild';
                        patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, json200List.size()).respond(new HTTPRequest());

                    // APIリクエスト送信
                    }else {
                        patchRes = APIRequest.sendPostRequest(accessToken, jsonBody);
                    }

                    // リクエスト結果をレコード単位でリストに格納
                    if(patchRes.getStatusCode() == 200) {
                        patchResList.addAll((List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class));
                    }else {
                        errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                    }
                }catch(Exception e) {
                    errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
                }
            }
            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // リクエスト結果格納用マップ  Map<契約商品ID, Map<作成パターン, レコード作成結果>>
                Map<String, Map<String, QCIS_APIRes>> resultRecMap = new Map<String, Map<String, QCIS_APIRes>>();
                // 作成パターン名称マップ
                Map<String, String> createPttrnMap = this.mapValPattern.get('mappingAcctCiMstChild').get('createPttrn');

                // リクエスト結果を突合用マップに格納
                Integer i = 0;
                for(String cntrId : keyList) {
                    resultRecMap.put(cntrId, new Map<String, QCIS_APIRes>());
                    for(String createPttrn : keyMap.get(cntrId)) {
                        // 付帯メニュー・窓情報
                        resultRecMap.get(cntrId).put(createPttrn, patchResList[i]);
                        i ++;
                    }
                }

                // リクエスト結果が成功の場合は契約商品にIDを連携し、エラーの場合はARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // マップからリクエスト結果を取り出す
                    Map<String, QCIS_APIRes> result = resultRecMap.get(ci.Id);
                    // 契約商品.設定料金アイテム（需要家別）情報の値をリセット
                    ci.CMN_AccountChargeItemMasterInfo__c = '';
                    // リクエスト結果を取り出せなかった場合は処理対象外のため、ここで終了
                    if(result == null) {
                        continue;
                    }
                    // 作成パターン単位に結果を確認
                    for(String createPttrn : createPttrnMap.keySet()) {
                        QCIS_APIRes resultRec = result.get(createPttrn);

                        // エラー発生の場合、連携エラーにする
                        if(resultRec != null && !resultRec.errors.isEmpty()) {
                            ci.CMN_LinkSts__c = LINKSTS_ERR;
                            ci.CMN_LinkErrorDetail__c = ('QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + resultRec.errors).left(255);
                            continue;

                        // 作成に成功した場合、契約商品.設定料金アイテム（需要家別）情報にレコードIDを設定
                        }else {
                            String createPttrnLabel = createPttrnMap.get(createPttrn);
                            String resultRecId = resultRec?.id ?? '';
                            ci.CMN_AccountChargeItemMasterInfo__c += createPttrnLabel + '①：' + resultRecId + '\n';
                            ci.CMN_AccountChargeItemMasterInfo__c += createPttrnLabel + '②：' + '\n';
                            ci.CMN_AccountChargeItemMasterInfo__c += createPttrnLabel + '③：' + '\n';
                        }
                    }
                    // 連携エラーの場合、設定料金アイテム（需要家別）情報を空白に設定
                    if(ci.CMN_LinkSts__c == LINKSTS_ERR) {
                        ci.CMN_AccountChargeItemMasterInfo__c = '';
                    }
                    // Apexテスト実行時かつARVE契約商品更新エラーパターンの場合、更新が失敗する値を設定する
                    if(Test.isRunningTest()) {
                        if(this.resPattern == 'contractItemIllegalError') {
                            ci.CMN_Product2__c = '01tXX000000XXXXXXX';
                        }
                    }
                }
            }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS設定料金アイテム（需要家別）マスタ' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * QuickCIS※I／F連携情報の更新
     * @param tgtMap ARVE契約商品マップ
     * @param accessToken アクセストークン
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @param qcisLnkgMngMap QuickCIS※I／F連携情報マップ
     * @return String エラーメッセージ
     * @throws なし
     * @see CMN_RestAPIRequest
     */
    public String updateLinkageManagement(
        Map<Id, CMN_ContractItem__c> tgtMap, String accessToken,
        Map<String, CMN_QuickCISRecord> qcisCntrMap,
        Map<String, CMN_QuickCISRecord> qcisLnkgMngMap) {

        // 更新用QuickCIS※I／F連携情報リスト  List<Map<項目名, 設定値>>
        List<Map<String, String>> updQcisLnkgMngList = new List<Map<String, String>>();

        // マッピングデータを生成
        for(CMN_ContractItem__c ci : tgtMap.values()) {
            // IF連携OBJのSFID
            String qcisLnkgMngId = ci.CMN_LinkageManagementSfid__c;
            // ※I／F連携情報
            CMN_QuickCISRecord qcisLnkgMng = qcisLnkgMngMap.get(qcisLnkgMngId);
            // ※I／F連携情報が取得できなかった場合は処理をスキップ
            if(qcisLnkgMng == null) {
                continue;
            }
            // 作成用マッピングデータを生成
            Map<String, String> mapping = mappingLnkgMng(ci, qcisCntrMap);
            // 更新用QuickCIS※I／F連携情報マップに格納
            updQcisLnkgMngList.add(mapping);
        }

        // APIリクエスト（QuickCIS※I／F連携情報の更新）
        String errMsg;
        if(!updQcisLnkgMngList.isEmpty()) {
            // 作成・更新用JSONリスト（1件ごとの更新内容を保持）
            List<String> jsonList = new List<String>();
            // 1件ずつJSON文字列に変換
            for(Map<String, String> mapping : updQcisLnkgMngList) {
                String json = '{"attributes":{"type":"dcis2__LinkageManagement__c","referenceId":' + mapping.get('Id') + '}';
                for(String fieldName : mapping.keySet()) {
                    json += ',"' + fieldName + '":' + mapping.get(fieldName);
                }
                jsonList.add(json);
            }
            // JSONを1つの文字列にマージ
            String jsonBody = '{"records":[' + String.join(jsonList, '},') + '}]}';

            // リクエスト結果マップ
            Map<String, QCIS_APIRes> resultMap = new Map<String, QCIS_APIRes>();

            // リクエスト送信
            try {
                HttpResponse patchRes;
                // Apexテスト実行時、モックデータを返す
                if(Test.isRunningTest()) {
                    String pattern = this.resPattern.contains('updateLinkageManagement') ? this.resPattern.split('_')[1] : 'updateLinkageManagement';
                    patchRes = new CMN_ContractToQuickCISAPIRequestMock(pattern, jsonList.size()).respond(new HTTPRequest());

                // APIリクエスト送信
                }else {
                    patchRes = APIRequest.sendPatchRequest(accessToken, jsonBody);
                }

                // リクエスト結果をレコード単位でマップに格納
                if(patchRes.getStatusCode() == 200) {
                    List<CMN_ContractItem__c> tgtList = tgtMap.values();
                    List<QCIS_APIRes> patchResList = (List<QCIS_APIRes>)JSON.deserialize(patchRes.getBody(), List<QCIS_APIRes>.class);
                    for(QCIS_APIRes res : patchResList) {
                        resultMap.put(res.id, res);
                    }
                }else {
                    errMsg = 'ステータスコード' + patchRes.getStatusCode() ;
                }
            }catch(Exception e) {
                errMsg = e.getTypeName() + ': ' + e.getMessage() + e.getStackTraceString();
            }

            // リクエスト結果を1件ずつ確認
            if(String.isBlank(errMsg)) {
                // リクエスト結果がエラーの場合、ARVE契約商品の連携ステータスを更新
                for(CMN_ContractItem__c ci : tgtMap.values()) {
                    // マップからリクエスト結果を取り出す
                    QCIS_APIRes result = resultMap.get(ci.CMN_LinkageManagementSfid__c);

                    // エラー発生の場合、連携エラーにする
                    if(result != null && !result.errors.isEmpty()) {
                        ci.CMN_LinkSts__c = LINKSTS_ERR;
                        ci.CMN_LinkErrorDetail__c = ('QuickCIS※I／F連携情報' + LINKERRORDETAIL_FAILED + '：' + result.errors).left(255);
                    }
                }
            }
        }
        // 全体で発生したエラーを返す（ない場合はnullを返す）
        if(!String.isBlank(errMsg)) {
            errMsg = 'QuickCIS※I／F連携情報' + LINKERRORDETAIL_FAILED + '：' + errMsg;
        }
        return errMsg;
    }


    /**
     * ARVE契約商品の連携ステータスを連携済みに更新
     * @param tgtList ARVE契約商品リスト
     * @return List<CMN_ContractItem__c> ARVE契約商品リスト
     * @throws なし
     * @see なし
     */
    public List<CMN_ContractItem__c> changeLinkStsLinked(List<CMN_ContractItem__c> tgtList) {

        for(CMN_ContractItem__c ci : tgtList) {
            ci.CMN_LinkSts__c = LINKSTS_LINKED;
            ci.CMN_LinkErrorDetail__c = '';
        }
        return tgtList;
    }


    // ----------------------------------------
    // 内部メソッド
    // ----------------------------------------

    /**
     * クラス変数のマッピング置換用マップに初期値を設定
     * @param なし
     * @return なし
     * @throws なし
     * @see なし
     */
    private void setMapValPattern() {

        //マッピング置換用マップ
        this.mapValPattern = new Map<String, Map<String, Map<String, String>>>();

        // マッピング置換内容生成：※電力契約
        this.mapValPattern.put('mappingContract', new Map<String, Map<String, String>>{
            // 業務用/産業用区分
            'industryKbn' => new Map<String, String>{
                '業務用' => 'business',
                '産業用' => 'industry'
            },
            // 大口フラグ
            'largeCustomerFlg' => new Map<String, String>{
                'true' => '大口',
                'false' => 'その他'
            },
            // 業務種別
            'businessTypeGS' => new Map<String, String>{
                '2：高圧' => '2',
                '3：特高' => '3'
            },
            // 業務種別（ラベル）
            'businessTypeLabel' => new Map<String, String>{
                '2：高圧' => '高圧',
                '3：特高' => '特高'
            },
            // 最低引取電力量算出単価時間
            'loadFactor' => new Map<String, String>{
                'P01080101;P0108013O' => '250',
                'P01080142;P0108013S;P01080141;P0108013R' => '300'
            },
            // 検針区分
            'powerAmountMeasuringTypeGS' => new Map<String, String>{
                '1：繰上' => '1',
                '2：分散' => '2'
            },
            // 契約電力決定方式
            'powerContractProcessGS' => new Map<String, String>{
                'ONDEMAND：実量制' => 'ONDEMAND',
                'PRIORAGREEMENT：協議制' => 'PRIORAGREEMENT'
            },
            // 契約決定方法
            'determineConnectionMethodGS' => new Map<String, String>{
                'ONDEMAND：実量制' => '3',
                'PRIORAGREEMENT：協議制' => '4'
            },
            // EP電力区分（検針区分＝"1：繰上"、単価情報="2024年度単価"）
            'ePPowerDiv1_2024' => new Map<String, String>{
                '特高' => 'ExtraHighPressure_advance',
                '以上' => 'BigHighPressure_advance',
                '未満' => 'SmallHighPressure_advance'
            },
            // EP電力区分（検針区分＝"2：分散"、単価情報="2024年度単価"）
            'ePPowerDiv2_2024' => new Map<String, String>{
                '特高' => 'ExtraHighPressure',
                '以上' => 'BigHighPressure',
                '未満' => 'SmallHighPressure'
            },
            // EP電力区分（検針区分＝"1：繰上"、単価情報="2025年度単価"）
            'ePPowerDiv1_2025' => new Map<String, String>{
                '特高' => 'ExtraHighPressure_advance_2025',
                '以上' => 'BigHighPressure_advance_2025',
                '未満' => 'SmallHighPressure_advance_2025'
            },
            // EP電力区分（検針区分＝"2：分散"、単価情報="2025年度単価"）
            'ePPowerDiv2_2025' => new Map<String, String>{
                '特高' => 'ExtraHighPressure_2025',
                '以上' => 'BigHighPressure_2025',
                '未満' => 'SmallHighPressure_2025'
            },
            // ご連絡先電話番号区分
            'contactPhoneClassificationGS' => new Map<String, String>{
                '1:自宅' => '1',
                '2:携帯' => '2',
                '3:家族・親族' => '3',
                '4:配偶者' => '4',
                '5:家主・管理人' => '5',
                '6:事務所' => '6',
                '9:その他' => '9'
            },
            // 需要者(発電者)電話番号区分1
            'customerPhoneClassification1GS' => new Map<String, String>{
                '1:自宅' => '1',
                '2:携帯' => '2',
                '3:家族・親族' => '3',
                '4:配偶者' => '4',
                '5:家主・管理人' => '5',
                '6:事務所' => '6',
                '9:その他' => '9'
            },
            // 需要者(発電者)電話番号区分2
            'customerPhoneClassification2GS' => new Map<String, String>{
                '1:自宅' => '1',
                '2:携帯' => '2',
                '3:家族・親族' => '3',
                '4:配偶者' => '4',
                '5:家主・管理人' => '5',
                '6:事務所' => '6',
                '9:その他' => '9'
            },
            // 延滞利息端数処理位置
            'latePaymentInterestPos' => new Map<String, String>{
                '円未満' => '0',
                '10円未満' => '10',
                '100円未満' => '100'
            },
            // 延滞利息端数処理方法
            'latePaymentInterestMethod' => new Map<String, String>{
                '切捨' => '1',
                '四捨五入' => '2',
                '切上' => '3'
            },
            // 通知方法
            'alertNotifierTypeGS' => new Map<String, String>{
                '振込票（QCIS）' => 'hurikomiQcis',
                '振込票（請求基盤）' => 'hurikomiIb',
                '適格請求書' => 'invoiceDispatch',
                '振込票（QCIS）;適格請求書' => 'hurikomiQcisAndInvoiceDispatch',
                '適格請求書;振込票（QCIS）' => 'hurikomiQcisAndInvoiceDispatch',
                '振込票（請求基盤）;適格請求書' => 'hurikomiIbAndInvoiceDispatch',
                '適格請求書;振込票（請求基盤）' => 'hurikomiIbAndInvoiceDispatch',
                'ポータル' => 'portal'
            },
            // 災害特措区分
            'specialDisasterClass' => new Map<String, String>{
                '災害特措' => 'SpecialDisaster',
                '新災害特措' => 'NewSpecialDisaster',
                '災害特措ベーシック' => 'SpecialDisasterBasic',
                '新災害特措＋災害特措ベーシック' => 'NewSpecialDisasterWithBasic',
                '災害特措＋災害特措ベーシック' => 'SpecialDisasterWithBasic'
            },
            // 支払方法
            'billingMethod' => new Map<String, String>{
                '口座振替' => 'D',
                'クレジットカード' => 'L'
            },
            // 口座振替方法
            'accountTransfer' => new Map<String, String>{
                '指定日' => '1',
                '月末' => '2',
                '期日' => '3'
            },
            // 口座照合ステータス
            'accountRequestStatus' => new Map<String, String>{
                '照合依頼中' => '01',
                '照合済み' => '02'
            },
            // 預金種別
            'depositType' => new Map<String, String>{
                '普通' => '1',
                '当座' => '2',
                '貯蓄' => '4',
                'その他' => '9'
            },
            // 振込詳細区分
            'directDepositKbn' => new Map<String, String>{
                'SMS' => '01',
                'パーフェクト口座' => '02'
            },
            // 請求方式
            'invoiceMethod' => new Map<String, String>{
                '締め日制' => 'Z1',
                '月分制' => 'Z2'
            },
            // 請求明細非表示フラグ
            'billingDetailNoDisplayFlg' => new Map<String, String>{
                'true' => 'X',
                'false' => ''
            },
            // 支払条件
            'paymentCondition' => new Map<String, String>{
                '一般契約：ZA01' => 'ZA01',
                '入札用：ZN01' => 'ZN01',
                '災害特措用：ZS01' => 'ZS01'
            }
        });
        // マッピング置換内容生成：設定料金アイテム（需要家別）マスタ
        this.mapValPattern.put('mappingAcctCiMst', new Map<String, Map<String, String>>{
            // 付帯メニュー・窓情報
            'amowInfo' => new Map<String, String>{
                'CMN_BasicUnitPrice__c_Under500' => 'W001',
                'CMN_BasicUnitPrice__c_Over500' => 'W002',
                'CMN_ElectricityUnitPrice__c' => 'W003',
                'CMN_ElectricityUnitPriceMorning__c' => 'W004',
                'CMN_ElectricityUnitPriceAfternoon__c' => 'W005',
                'CMN_ElectricityUnitPriceEvening__c' => 'W006',
                'CMN_ElectricityUnitPriceNightHoliday__c' => 'W007',
                'CMN_ElectricityUnitPricePeak__c' => 'W008',
                'CMN_ElectricityUnitPriceSummerDay__c' => 'W009',
                'CMN_ElectricityUnitPriceOtherDay__c' => 'W010',
                'CMN_ElectricityUnitPriceNight__c' => 'W011',
                'CMN_ElectricityUnitPriceHoliday__c' => 'W012',
                'CMN_ElectricityUnitPriceSummer__c' => 'W013',
                'CMN_ElectricityUnitPriceOther__c' => 'W014',
                'CMN_ElectricityUnitPriceDaytime__c' => 'W015'
            },
            // ブレンド対象料金アイテム種別
            'blendingTargetPriceItemType' => new Map<String, String>{
                'W001' => 'BaseLoad',
                'W002' => 'BaseLoad',
                'W003' => 'BaseLoad',
                'W004' => 'BaseLoad',
                'W005' => 'BaseLoad',
                'W006' => 'BaseLoad',
                'W007' => 'BaseLoad',
                'W008' => 'PeakLoad',
                'W009' => 'BaseLoad',
                'W010' => 'BaseLoad',
                'W011' => 'BaseLoad',
                'W012' => 'BaseLoad',
                'W013' => 'BaseLoad',
                'W014' => 'BaseLoad',
                'W015' => 'BaseLoad'
            },
            // 付帯メニュー・窓情報
            'amowInfoName' => new Map<String, String>{
                'W001' => '基本単価',
                'W002' => '基本単価',
                'W003' => '電力量料金（１窓）',
                'W004' => '電力量料金（朝）',
                'W005' => '電力量料金（昼）',
                'W006' => '電力量料金（晩）',
                'W007' => '電力量料金（夜・日曜/祝日）',
                'W008' => '電力量料金（ピーク）',
                'W009' => '電力量料金（夏季昼間）',
                'W010' => '電力量料金（他季昼間）',
                'W011' => '電力量料金（夜間）',
                'W012' => '電力量料金（日曜/祝日）',
                'W013' => '電力量料金（夏季）',
                'W014' => '電力量料金（その他季）',
                'W015' => '電力量料金（昼間）'
            }
        });
        // マッピング置換内容生成：設定料金アイテム（需要家別）マスタ（子）
        this.mapValPattern.put('mappingAcctCiMstChild', new Map<String, Map<String, String>>{
            // 作成パターン
            'createPttrn' => new Map<String, String>{
                'notIndividual' => '個別単価なし',
                'individual' => '個別単価',
                'normal1' => '通常単価1',
                'normal2' => '通常単価2'
            }
        });
    }


    /**
     * JSON文字列をQuickCISレコードタイプマップに変換
     * @param jsonStr JSON文字列
     * @return Map<String, Map<String, String>> QuickCISレコードタイプ
     * @throws なし
     * @see なし
     */
    @TestVisible
    private Map<String, Map<String, String>> deserializeRtMap(String jsonStr) {

        // QuickCISレコードタイプマップ
        Map<String, Map<String, String>> rtMap = new Map<String, Map<String, String>>();
        // JSON文字列をマップ型に変換する
        Map<String, Object> getResMap = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
        for(Object recObj : (List<Object>)getResMap.get('records')) {
            Map<String, Object> rec = (Map<String, Object>)recObj;
            // JSON文字列からオブジェクト名、レコードタイプID、レコードタイプAPI名を取得
            String sobjectType = (String)rec.get('SobjectType');
            String id = (String)rec.get('Id');
            String developerName = (String)rec.get('DeveloperName');
            // 取得情報をマップに格納
            if(rtMap.containsKey(sobjectType)) {
                rtMap.get(sobjectType).put(developerName, id);
            }else {
                rtMap.put(sobjectType, new Map<String, String>{developerName => id});
            }
        }
        return rtMap;
    }


    /**
     * JSON文字列をQuickCIS※料金メニューマップに変換
     * @param jsonStr JSON文字列
     * @return Map<String, String> QuickCIS※料金メニュー
     * @throws なし
     * @see なし
     */
    @TestVisible
    private Map<String, String> deserializeChargeMenuMap(String jsonStr) {

        // QuickCIS※料金メニューマップ
        Map<String, String> ChargeMenuMap = new Map<String, String>();
        // JSON文字列から取得レコードを取り出しマップに格納
        Map<String, Object> getResMap = (Map<String, Object>)JSON.deserializeUntyped(jsonStr);
        for(Object recObj : (List<Object>)getResMap.get('records')) {
            Map<String, Object> rec = (Map<String, Object>)recObj;
            // key：料金メニュー名、value：レコードID
            ChargeMenuMap.put((String)rec.get('Name'), (String)rec.get('Id'));
        }
        return ChargeMenuMap;
    }


    /**
     * QuickCIS取引先の作成・更新用マッピングデータを生成
     * @param ci ARVE契約商品
     * @param qcisAcct QuickCIS取引先
     * @param acctRtMap QuickCIS取引先レコードタイプマップ
     * @param nowTime 現在時刻（yyyyMMddHHmmss）
     * @return Map<String, String> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private Map<String, String> mappingAccount(
        CMN_ContractItem__c ci, CMN_QuickCISRecord qcisAcct, 
        Map<String, String> acctRtMap, String nowTime) {

        // マッピング格納用マップ
        Map<String, String> mapping = new Map<String, String>();
        // マッピング用変数
        // ID
        String acctId = qcisAcct != null ? qcisAcct.Id : null;
        if(acctId != null) {
            acctId = '"' + acctId + '"';
        }
        // 契約名義
        String keiyakuMeigi = (ci.CMN_DemandLocationLastName__c ?? '')
                            + '　'
                            + (ci.CMN_DemandLocationFirstName__c ?? '');
        // 町名・番地(請求先)
        String billingStreet = (ci.CMN_BillingSection__c ?? '')
                             + (ci.CMN_BillingBlock1__c ?? '')
                             + (ci.CMN_BillingBlock2__c ?? '')
                             + (ci.CMN_BillingBlock3__c ?? '');
        // 丁目・番地(請求先)
        String billingSectionName = (ci.CMN_BillingBlock1__c ?? '')
                                 + (ci.CMN_BillingBlock2__c ?? '');
        // 契約場所_第一連絡先
        String[] renrakTel = new String[3];
        if(!String.isBlank(ci.CMN_DemandLocationTellPhone__c)) {
            renrakTel = ci.CMN_DemandLocationTellPhone__c.split('-');
            if(renrakTel.size() != 3) {
                renrakTel = new String[3];
            }
        }
        // 顧客ID
        // ※顧客IDリストからランダムな値を設定
        String clientId = this.clientIdList[Math.mod(Math.round(Math.random()*1000), clientIdList.size())];
        // マッピング
        mapping.put('Id', acctId);                                                                        // ID
        mapping.put('Name', convertNull(keiyakuMeigi));                                                   // 取引先名
        mapping.put('C_CompanyName__c', convertNull(keiyakuMeigi));                                       // 企業名
        mapping.put('BillingStreet', convertNull(billingStreet));                                         // 町名・番地(請求先)
        mapping.put('C_BillingSectionName__c', convertNull(billingSectionName));                          // 丁目・番地(請求先)
        mapping.put('dcis2__RenrakuTelShigai__c', convertNull(renrakTel[0]));                             // ※連絡先（市外局番）
        mapping.put('dcis2__RenrakuTelShinai__c', convertNull(renrakTel[1]));                             // ※連絡先（市内局番）
        mapping.put('dcis2__RenrakuTelKanyusha__c', convertNull(renrakTel[2]));                           // ※連絡先（加入者番号）

        // カスタムメタデータを基にマッピングする
        mapping = mpgCmnClass.mapContractToQuickCIS(ci, mapping, 'mappingAccount');

        // マッピング（新規の場合）
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C || (ci.CMN_LinkageKbn__c != LINKAGEKBN_C && qcisAcct == null)) {
            // ※ローカル認証ID
            String localUserId = nowTime + ci.Name.right(7) + '@tepco.co.jp.invalid';
            // 取引先ID※固定値
            Map<String, object> finalAcctIdMap =
                (Map<String, Object>)JSON.deserializeUntyped(System.label.CMN_ContractToQuickCIS_AccountId);

            mapping.put('BillingCountry', '"日本"');                                                                 // 国(請求先)
            mapping.put('dcis2__LocalUserId__c', '"' + localUserId + '"');                                           // ※ローカル認証ID
            mapping.put('dcis2__AccountId__c', convertNull(ci.CMN_VisualizationCustomerNum__c));                     // ※CISお客様番号
            mapping.put('dcis2__Agency__c', '"' + String.valueOf(finalAcctIdMap.get('Agency')) + '"');               // ※販売店
            mapping.put('dcis2__PowerRetailer__c', '"' + String.valueOf(finalAcctIdMap.get('PowerRetailer')) + '"'); // ※ホワイトラベル
            mapping.put('dcis2__Wholesale__c', '"' + String.valueOf(finalAcctIdMap.get('Wholesale')) + '"');         // ※卸
            mapping.put('dcis2__PaymentMethodGS__c', '"SummaryInvoice"');                                            // ※支払い方法
            mapping.put('RecordTypeId', convertNull(acctRtMap.get('BusinessAccount')));                              // レコードタイプID
            mapping.put('dcis2__StatusGS__c', '"4"');                                                                // ※ユーザステータス
            mapping.put('C_CustomerControlExcludedFlg__c', '"true"');                                                // 顧客管理対象外フラグ
            mapping.put('C_CustomerMasterRegistrationFlg__c', '"false"');                                            // 顧客マスタ登録フラグ
            mapping.put('C_ClientID__c', convertNull(clientId));                                                     // 顧客ID
        }
        return mapping;
    }


    /**
     * QuickCIS※電力契約の作成・更新用マッピングデータを生成
     * @param ci ARVE契約商品
     * @param cntrRtMap QuickCIS※電力契約レコードタイプマップ
     * @param qcisAccMap QuickCIS取引先マップ
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @param qcisChargeMenuMap ※料金メニューマップ
     * @param pilh 支払情報（最新履歴）
     * @return Map<String, String> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private Map<String, String> mappingContract(
        CMN_ContractItem__c ci, Map<String, String> cntrRtMap, Map<String, CMN_QuickCISRecord> qcisAccMap,
        Map<String, CMN_QuickCISRecord> qcisCntrMap, Map<String, String> qcisChargeMenuMap, CMN_PaymentInfo__c pilh) {

        // マッピング格納用マップ  Map<項目名, 値>
        Map<String, String> mapping = new Map<String, String>();
        // マッピング置換用マップ
        Map<String, Map<String, String>> valPattern = this.mapValPattern.get('mappingContract');

        // レコードID
        // QuickCIS契約番号に合致するQuickCIS電力契約が存在する場合はそのID、しない場合はnull
        String recId = qcisCntrMap.get(ci.CMN_QCISContractId__c)?.Id;
        // QuickCIS契約番号の継続利用対象の複製契約の場合はIdを空で連携
        if(ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C){
            recId = null;
        }
        // QuickCIS電力契約が存在する場合、ダブルクォーテーションで囲む
        if(recId != null) {
            recId = '"' + recId + '"';
        }

        // 会員ID（※CISお客様番号がARVE契約商品.見える化まとめコードと等しいQuickCIS取引先のID）
        String accId = qcisAccMap.get(ci.CMN_VisualizationCustomerNum__c)?.Id;

        // 商品ID
        String stockKeepingUnit = ci.CMN_StockKeepingUnit__c;
        if(Test.isRunningTest()) {
            stockKeepingUnit = stockKeepingUnit.removeEnd('UNIT');
        }
        // 料金メニュー名（商品ID + 供給地点特定番号（上2桁） + 単価情報）
        String chargeMenuName = stockKeepingUnit
                                + ci.CMN_SupplyPointSpecificNum__c?.left(2)
                                + ci.CMN_UnitPriceKbn__c?.left(4);
        // カスタムメタデータ型「料金メニュー」
        CMN_QuickCISChargeMenu_Setting__mdt chargeMenuSetting = CMN_QuickCISChargeMenu_Setting__mdt.getInstance(chargeMenuName);
        // 料金メニューID
        String chargeMenu = qcisChargeMenuMap.get(chargeMenuSetting?.CMN_ChargeMenu__c);
        if(chargeMenu != null) {
            chargeMenu = '"' + chargeMenu + '"';
        }
        // 使用調整項単価
        String adjustedUnitPrice = chargeMenuSetting?.CMN_AdjustedUnitPrice__c;
        // 使用調整項単価（ピーク）
        String adjustedUnitPriceForPeak = chargeMenuSetting?.CMN_AdjustedUnitPriceForPeak__c;
        // ベースロード料金メニュー  SFID
        String baseLoadInvoiceMenu = qcisChargeMenuMap.get(chargeMenuSetting?.CMN_BaseLoadInvoiceMenu__c);
        if(baseLoadInvoiceMenu != null) {
            baseLoadInvoiceMenu = '"' + baseLoadInvoiceMenu + '"';
        }
        // ピークロード料金メニューSFID
        String peakLoadInvoiceMenu = qcisChargeMenuMap.get(chargeMenuSetting?.CMN_PeakLoadInvoiceMenu__c);
        if(peakLoadInvoiceMenu != null) {
            peakLoadInvoiceMenu = '"' + peakLoadInvoiceMenu + '"';
        }

        // マッピング用変数
        // 業務用/産業用区分
        String industryKbn = valPattern.get('industryKbn').get(ci.CMN_IndustryKbn__c);
        // 大口フラグ
        String largeCustomerFlg = valPattern.get('largeCustomerFlg').get(String.valueOf(ci.CMN_LargeCustomerFlg__c)); 
        // 契約開始日
        Date contractStartDate = ci.CMN_ContractStartDate__c;
        // 需給開始希望月
        String supplyDemandStartDate;
        if(ci.CMN_SupplyDemandStartDate__c != null) {
            Date sdsDate = ci.CMN_SupplyDemandStartDate__c;
            supplyDemandStartDate = String.valueOf(sdsDate.year()) + String.valueOf(sdsDate.month()).leftPad(2, '0');
        }
        // 業務種別
        String businessTypeGS = valPattern.get('businessTypeGS').get(ci.CMN_BusinessType__c);
        // 業務種別（ラベル）
        String businessTypeLabel = valPattern.get('businessTypeLabel').get(ci.CMN_BusinessType__c);
        // 最低引取電力量算出単価時間
        Integer loadFactor;
        if(ci.CMN_UnitPriceKbn__c == '2024年度単価') {
            for(String sku : valPattern.get('loadFactor').keySet()) {
                if(sku.contains(stockKeepingUnit)) {
                    loadFactor = Integer.valueOf(valPattern.get('loadFactor').get(sku));
                }
            }
        }
        // 検針区分
        String powerAmountMeasuringTypeGS = valPattern.get('powerAmountMeasuringTypeGS').get(ci.CMN_PowerAmountMeasuringType__c);
        // 計量日（高圧）
        Integer highVAcutualMaterReadingDate;
        if(!String.isBlank(ci.CMN_AcutualMaterReadingDate__c)) {
            highVAcutualMaterReadingDate = Integer.valueOf(ci.CMN_AcutualMaterReadingDate__c);
        }
        // 契約電力決定方式
        String powerContractProcessGS = valPattern.get('powerContractProcessGS').get(ci.CMN_PowerContractProcess__c);
        // 契約決定方法
        String determineConnectionMethodGS = valPattern.get('determineConnectionMethodGS').get(ci.CMN_PowerContractProcess__c);
        // 契約電圧区分
        String contactVoltageDiv;
        Decimal supplyVoltage = ci.CMN_SupplyVoltage__c;
        if(3000 <= supplyVoltage && supplyVoltage <= 6000) {
            contactVoltageDiv = '1';
        }else if(10000 <= supplyVoltage && supplyVoltage <= 30000) {
            contactVoltageDiv = '2';
        }else if(supplyVoltage == 60000) {
            contactVoltageDiv = '3';
        }else if(60000 < supplyVoltage && supplyVoltage <= 140000) {
            contactVoltageDiv = '4';
        }else if(supplyVoltage == 275000) {
            contactVoltageDiv = '5';
        }
        // 契約電力ランク
        String powerContractRank = '未満'; 
        if(businessTypeGS == '2' && 500 <= ci.CMN_PowerContract__c) {
                powerContractRank = '以上';
        }else if(businessTypeGS == '3') {
            powerContractRank = '特高';
        }
        /** 20260306 USE DEL
        // EP電力区分
        String ePPowerDiv;
        if(!String.isBlank(powerAmountMeasuringTypeGS) && !String.isBlank(ci.CMN_UnitPriceKbn__c)) {
            // マッピングキー
            String ePPowerDivKey = 'ePPowerDiv' + powerAmountMeasuringTypeGS + '_' + ci.CMN_UnitPriceKbn__c.left(4);
            // マッピングから値を取得
            ePPowerDiv = valPattern.get(ePPowerDivKey).get(powerContractRank);
        }
        20260306 USE DEL */
        
        // 需要者(発電者)窓口連絡先氏名
        String customerCounterName = (ci.CMN_BillingLastName__c ?? '')
                                    + (ci.CMN_BillingFirstName__c ?? '');
        // ご連絡先電話番号
        String[] contactPhone = new String[3];
        if(!String.isBlank(ci.CMN_BillingTellPhone__c)) {
            contactPhone = ci.CMN_BillingTellPhone__c.split('-');
            if(contactPhone.size() != 3) {
                contactPhone = new String[3];
            }
        }
        // ご連絡先電話番号区分
        String contactPhoneClassificationGS = valPattern.get('contactPhoneClassificationGS').get(ci.CMN_BillingPhoneKbn1__c);
        // ご連絡先都道府県
        String contactPrefNameGS;
        if(!String.isBlank(ci.CMN_BillingStateCode__c)) {
            contactPrefNameGS = String.valueOf(Integer.valueOf(ci.CMN_BillingStateCode__c));
        }
        // ご連絡先丁目番地
        String contactStreetName = (ci.CMN_BillingSection__c ?? '')
                                    + (ci.CMN_BillingBlock1__c ?? '')
                                    + (ci.CMN_BillingBlock2__c ?? '')
                                    + (ci.CMN_BillingBlock3__c ?? '');
        // 契約場所_第一連絡先
        String[] dlTellPhone = new String[3];
        if(ci.CMN_DemandLocationTellPhone__c != null) {
            dlTellPhone = ci.CMN_DemandLocationTellPhone__c.split('-');
            if(dlTellPhone.size() != 3) {
                dlTellPhone = new String[3];
            }
        }
        // 需要者(発電者)電話番号区分1
        String customerPhoneClassification1GS = valPattern.get('customerPhoneClassification1GS').get(ci.CMN_DemandLocationPhoneKbn1__c);
        // 契約場所_第二連絡先
        String[] dlMobilePhone = new String[3];
        if(ci.CMN_DemandLocationMobilePhone__c != null) {
            dlMobilePhone = ci.CMN_DemandLocationMobilePhone__c.split('-');
            if(dlMobilePhone.size() != 3) {
                dlMobilePhone = new String[3];
            }
        }
        // 需要者(発電者)電話番号区分2
        String customerPhoneClassification2GS = valPattern.get('customerPhoneClassification2GS').get(ci.CMN_DemandLocationPhoneKbn2__c);
        // 需要者(発電者)丁目番地
        String customerStreetName = (ci.CMN_DemandLocationSection__c ?? '')
                                    + (ci.CMN_DemandLocationBlock1__c ?? '')
                                    + (ci.CMN_DemandLocationBlock2__c ?? '')
                                    + (ci.CMN_DemandLocationBlock3__c ?? '');
        // 需要者(発電者)都道府県
        String customerPrefNameGS;
        if(!String.isBlank(ci.CMN_DemandLocationStateCode__c)) {
            // 0埋め2桁 -> 0埋めなしの1桁に変換
            customerPrefNameGS = String.valueOf(Integer.valueOf(ci.CMN_DemandLocationStateCode__c));
        }
        // 企業特約グループ番号
        String specialAgreementGroupNo;
        if(ci.CMN_UnitPriceKbn__c == '2024年度単価') {
            specialAgreementGroupNo = ci.CMN_SpecialAgreementGroupNo__c;
        }
        // 再エネ減免率適用期間（開始年月）
        Integer renewableEnergiesExemptionRateStart;
        if(!String.isBlank(ci.CMN_RenewableEnergiesStartPeriod__c)) {
            renewableEnergiesExemptionRateStart = Integer.valueOf(ci.CMN_RenewableEnergiesStartPeriod__c);
        }
        // 再エネ減免率適用期間（終了年月）
        Integer renewableEnergiesExemptionRateEnd;
        if(!String.isBlank(ci.CMN_RenewableEnergiesEndPeriod__c)) {
            renewableEnergiesExemptionRateEnd = Integer.valueOf(ci.CMN_RenewableEnergiesEndPeriod__c);
        }
        // 合算請求締め日
        String summaryInvoiceClosingDate;
        if(!ci.CMN_DivisionBillingFlg__c && !String.isBlank(ci.CMN_PaymentInfo__r?.CMN_CombinedBillingDeadline__c)) {
            summaryInvoiceClosingDate = ci.CMN_PaymentInfo__r.CMN_CombinedBillingDeadline__c.left(2);
        }
        // 支払期限プラス日数（暦日）
        Integer paymentDueDatePlusCalendarDays;
        if(!String.isBlank(ci.CMN_PayDeadlinePlusDays__c)) {
            paymentDueDatePlusCalendarDays = Integer.valueOf(ci.CMN_PayDeadlinePlusDays__c);
        }
        // 延滞利息端数処理位置
        String latePaymentInterestPos = valPattern.get('latePaymentInterestPos').get(ci.CMN_LateInterestRoundPosition__c);
        // 延滞利息端数処理方法
        String latePaymentInterestMethod = valPattern.get('latePaymentInterestMethod').get(ci.CMN_LateInterestRoundMethod__c);
        // 分割数
        Integer splitCount;
        if(!String.isBlank(ci.CMN_DivisionNum__c)) {
            splitCount = Integer.valueOf(ci.CMN_DivisionNum__c);
        }
        // 分割時割合
        Decimal splitPercentageAmount;
        if(!String.isBlank(ci.CMN_DivisionRate__c)) {
            splitPercentageAmount = Decimal.valueOf(ci.CMN_DivisionRate__c);
        }
        // 指定月請求作成年月
        Integer specifiedMonthBillingCreationYearMonth;
        if(!String.isBlank(ci.CMN_SpecifiedMonthBillCreateDate__c)) {
            specifiedMonthBillingCreationYearMonth = Integer.valueOf(ci.CMN_SpecifiedMonthBillCreateDate__c);
        }
        // 前契約開始日
        Date prevContractStartDate = ci.CMN_OldJuyobasho__r?.ARV_ContractStart__c;
        prevContractStartDate = prevContractStartDate ?? ci.CMN_OldContractItem__r.CMN_ContractStartDate__c;
        // 前契約終了日
        Date prevContractEndDate = ci.CMN_OldJuyobasho__r?.ARV_ContractEnd__c;
        prevContractStartDate = prevContractStartDate ?? ci.CMN_OldContractItem__r.CMN_ContractEndDate__c;
        // 通知方法
        String alertNotifierTypeGS;
        if(ci.CMN_NotificationMethod__c == '郵送') {
            alertNotifierTypeGS = valPattern.get('alertNotifierTypeGS').get(ci.CMN_MailingContents__c);
        } else if(ci.CMN_NotificationMethod__c == 'ポータル') {
            alertNotifierTypeGS = valPattern.get('alertNotifierTypeGS').get('ポータル');
        }
        // 災害特措区分
        String specialDisasterClass = valPattern.get('specialDisasterClass').get(ci.CMN_DisasterMeasureKbn__c);
        // 支払方法
        String billingMethod = valPattern.get('billingMethod').get(ci.CMN_PaymentInfo__r.CMN_PaymentMethod__c);
        // 口座振替方法
        String accountTransfer = valPattern.get('accountTransfer').get(ci.CMN_PaymentInfo__r.CMN_BankAccTransferMethod__c);
        // 口座照合ステータス
        String accountRequestStatus = valPattern.get('accountRequestStatus').get(ci.CMN_PaymentInfo__r.CMN_BankAccMatchSts__c);
        // 預金種別
        String depositType = valPattern.get('depositType').get(ci.CMN_PaymentInfo__r.CMN_DepositType__c);
        if(ci.CMN_PaymentInfo__r.CMN_FinancialInstName__c == 'ゆうちょ銀行') {
            depositType = ci.CMN_PaymentInfo__r.CMN_PassbookNumUpper1Digit__c;
        }
        // 振込詳細区分
        String directDepositKbn = valPattern.get('directDepositKbn').get(ci.CMN_PaymentInfo__r.CMN_TransferDetailKbn__c);
        // 請求方式
        String invoiceMethod = valPattern.get('invoiceMethod').get(ci.CMN_PaymentInfo__r.CMN_InvoiceMethod__c);
        // 支払情報（履歴）.請求方式
        String invoiceMethodHistory = (pilh != null && !String.isBlank(pilh.CMN_InvoiceMethod__c)) ? valPattern.get('invoiceMethod').get(pilh.CMN_InvoiceMethod__c) : null;
        // 請求明細非表示フラグ
        String billingDetailNoDisplayFlg = valPattern.get('billingDetailNoDisplayFlg').get(String.valueOf(ci.CMN_PaymentInfo__r.CMN_BillingDetailNoDisplayFlg__c));
        // 支払条件
        String paymentCondition = valPattern.get('paymentCondition').get(ci.CMN_PaymentInfo__r.CMN_PaymentCondition__c);

        // 合算請求マスタ更新区分
        String SummaryInvoiceUpdateGS = ci.CMN_SummaryInvoiceMasterUpdateKbn__c;
        // QCIS電力契約.合算請求ID = Null かつ 契約商品.合算請求マスタ更新区分 が "更新"の場合
        if(String.isBlank(qcisCntrMap.get(ci.CMN_QCISContractId__c)?.SummaryInvoiceID) &&
           ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '更新'){
            //QCIS電力契約.合算請求マスタ更新区分 = 新規
            SummaryInvoiceUpdateGS = '新規';
        }

        // 元契約終了日
        String originalContractEndDate = qcisCntrMap.get(ci.CMN_QCISContractId__c)?.ContractEndDate;

        // 口座名義カナ1
        String bankAccNameKana1 = getBankAccNameKana(ci);

        // マッピングC_ManageAccount__c
        mapping.put('Id', recId);                                                                                        // ID
        mapping.put('RecordTypeId', convertNull(cntrRtMap.get('MainHighV')));                                            // レコードタイプID
        mapping.put('C_IndustryKbn__c', convertNull(industryKbn));                                                       // 業務用/産業用区分
        mapping.put('C_LargeCustomerFlg__c', convertNull(largeCustomerFlg));                                             // 大口フラグ
        mapping.put('dcis2__ContractStartDate__c', convertNull(contractStartDate));                                      // 契約開始日
        mapping.put('C_SupplyDemandDesiredStartMonth__c', convertNull(supplyDemandStartDate));                           // 需給開始希望月
        mapping.put('dcis2__BusinessTypeGS__c', convertNull(businessTypeGS));                                            // 業務種別
        mapping.put('dcis2__BusinessTypeLabel__c', convertNull(businessTypeLabel));                                      // 業務種別（ラベル）
        mapping.put('dcis2__ChargeMenu__c', chargeMenu);                                                                 // 料金メニュー
        mapping.put('C_LoadFactor__c', convertNull(loadFactor));                                                         // 最低引取電力量算出単価時間
        mapping.put('C_AdjustedUnitPrice__c', convertNull(adjustedUnitPrice));                                           // 使用調整項単価
        mapping.put('C_AdjustedUnitPriceForPeak__c', convertNull(adjustedUnitPriceForPeak));                             // 使用調整項単価（ピーク）
        mapping.put('dcis2__PowerAmountMeasuringTypeGS__c', convertNull(powerAmountMeasuringTypeGS));                    // 検針区分
        mapping.put('C_HighVAcutualMaterReadingDate__c', convertNull(highVAcutualMaterReadingDate));                     // 計量日（高圧）
        mapping.put('dcis2__PowerContractProcessGS__c', convertNull(powerContractProcessGS));                            // 契約電力決定方法
        mapping.put('dcis2__DetermineConnectionMethodGS__c', convertNull(determineConnectionMethodGS));                  // 契約決定方法
        //ARVE-5331 更新・削除かつ実量制の時は契約電力は変更しない
        if(!(ci.CMN_LinkageKbn__c != LINKAGEKBN_C && ci.CMN_PowerContractProcess__c == 'ONDEMAND：実量制')) {
            mapping.put('dcis2__HighVPowerContract__c', convertNull(ci.CMN_PowerContract__c));                           // 高圧契約電力(kW)   
        }
        mapping.put('C_ContactVoltageDiv__c', convertNull(contactVoltageDiv));                                           // 契約電圧区分
        mapping.put('C_PowerContractRank__c', convertNull(powerContractRank));                                           // 契約電力ランク
        // 20260306 USE DEL
        //mapping.put('C_EPPowerDiv__c', convertNull(ePPowerDiv));                                                         // EP電力区分
        mapping.put('dcis2__CustomerCounterName__c', convertNull(customerCounterName));                                  // 需要者(発電者)窓口連絡先氏名
        mapping.put('dcis2__ContactPhoneAreaCode__c', convertNull(contactPhone[0]));                                     // ご連絡先電話番号(市外局番)
        mapping.put('dcis2__ContactPhoneCityCode__c', convertNull(contactPhone[1]));                                     // ご連絡先電話番号(市内局番)
        mapping.put('dcis2__ContactPhoneSubscriberNumber__c', convertNull(contactPhone[2]));                             // ご連絡先電話番号(加入者番号)
        mapping.put('dcis2__ContactPhoneClassificationGS__c', convertNull(contactPhoneClassificationGS));                // ご連絡先電話番号区分
        mapping.put('dcis2__ContactPrefNameGS__c', convertNull(contactPrefNameGS));                                      // ご連絡先都道府県
        mapping.put('dcis2__ContactStreetName__c', convertNull(contactStreetName));                                      // ご連絡先丁目番地
        mapping.put('dcis2__CustomerCounterPhoneAreaCode__c', convertNull(dlTellPhone[0]));                              // 需要者(発電者)窓口電話番号（市外局番）
        mapping.put('dcis2__CustomerCounterPhoneCityCode__c', convertNull(dlTellPhone[1]));                              // 需要者(発電者)窓口電話番号（市内局番）
        mapping.put('dcis2__CustomerCounterPhoneCityCodeCustomerCoun__c', convertNull(dlTellPhone[2]));                  // 需要者(発電者)窓口電話番号（加入者番号）
        mapping.put('dcis2__CustomerPhoneAreaCode1__c', convertNull(dlTellPhone[0]));                                    // 需要者(発電者)電話番号(市外局番)1
        mapping.put('dcis2__CustomerPhoneCityCode1__c', convertNull(dlTellPhone[1]));                                    // 需要者(発電者)電話番号(市内局番)1
        mapping.put('dcis2__CustomerPhoneSubscriberNumber1__c', convertNull(dlTellPhone[2]));                            // 需要者(発電者)電話番号(加入者番号)1
        mapping.put('dcis2__CustomerPhoneClassification1GS__c', convertNull(customerPhoneClassification1GS));            // 需要者(発電者)電話番号区分1
        mapping.put('dcis2__CustomerPhoneAreaCode2__c', convertNull(dlMobilePhone[0]));                                  // 需要者(発電者)電話番号(市外局番)2
        mapping.put('dcis2__CustomerPhoneCityCode2__c', convertNull(dlMobilePhone[1]));                                  // 需要者(発電者)電話番号(市内局番)2
        mapping.put('dcis2__CustomerPhoneSubscriberNumber2__c', convertNull(dlMobilePhone[2]));                          // 需要者(発電者)電話番号(加入者番号)2
        mapping.put('dcis2__CustomerPhoneClassification2GS__c', convertNull(customerPhoneClassification2GS));            // 需要者(発電者)電話番号区分2
        mapping.put('dcis2__CustomerPrefNameGS__c', convertNull(customerPrefNameGS));                                    // 需要者(発電者)都道府県
        mapping.put('dcis2__CustomerStreetName__c', convertNull(customerStreetName));                                    // 需要者(発電者)丁目番地
        mapping.put('C_SpecialAgreementGroupNo__c', convertNull(specialAgreementGroupNo));                               // 企業特約グループ番号
        mapping.put('C_RenewableEnergiesExemptionRateStart__c', convertNull(renewableEnergiesExemptionRateStart));       // 再エネ減免率適用期間（開始年月）
        mapping.put('C_RenewableEnergiesExemptionRateEnd__c', convertNull(renewableEnergiesExemptionRateEnd));           // 再エネ減免率適用期間（終了年月）
        mapping.put('C_BaseLoadInvoiceMenu__c', baseLoadInvoiceMenu);                                                    // ベースロード料金メニュー
        mapping.put('C_PeakLoadInvoiceMenu__c', peakLoadInvoiceMenu);                                                    // ピークロード料金メニュー
        mapping.put('C_SummaryInvoiceClosingDate__c', convertNull(summaryInvoiceClosingDate));                           // 合算請求締め日
        mapping.put('C_PaymentDueDatePlusCalendarDays__c', convertNull(paymentDueDatePlusCalendarDays));                 // 支払期限プラス日数（暦日）
        mapping.put('C_LatePaymentInterestPos__c', convertNull(latePaymentInterestPos));                                 // 延滞利息端数処理位置
        mapping.put('C_LatePaymentInterestMethod__c', convertNull(latePaymentInterestMethod));                           // 延滞利息端数処理方法
        mapping.put('C_SplitCount__c', convertNull(splitCount));                                                         // 分割数
        mapping.put('C_SplitPercentageAmount__c', convertNull(splitPercentageAmount));                                   // 分割時割合
        mapping.put('C_SpecifiedMonthBillingCreationYearMonth__c', convertNull(specifiedMonthBillingCreationYearMonth)); // 指定月請求作成年月
        mapping.put('C_PrevContractStartDate__c', convertNull(prevContractStartDate));                                   // 前契約開始日
        mapping.put('C_PrevContractEndDate__c', convertNull(prevContractEndDate));                                       // 前契約終了日
        mapping.put('C_AlertNotifierTypeGS__c', convertNull(alertNotifierTypeGS));                                       // 通知方法
        mapping.put('C_SpecialDisasterClass__c', convertNull(specialDisasterClass));                                     // 災害特措区分
        mapping.put('C_SummaryInvoiceUpdateGS__c', convertNull(SummaryInvoiceUpdateGS));                                 // 合算請求マスタ更新区分
        mapping.put('C_AccountNameKana__c', convertNull(bankAccNameKana1));                                              // 口座名義カナ1※編集後の値
        mapping.put('C_BillingMethod__c', convertNull(billingMethod));                                                   // 支払方法
        mapping.put('C_AccountTransfer__c', convertNull(accountTransfer));                                               // 口座振替方法
        mapping.put('C_AccountRequestStatus__c', convertNull(accountRequestStatus));                                     // 口座照合ステータス
        mapping.put('C_DepositType__c', convertNull(depositType));                                                       // 預金種別
        mapping.put('C_DirectDepositKbn__c', convertNull(directDepositKbn));                                             // 振込詳細区分

        // カスタムメタデータを基にマッピングする
        mapping = mpgCmnClass.mapContractToQuickCIS(ci, mapping, 'mappingContract');

        // 合算請求ID
        // 契約商品.合算請求マスタ更新区分 が "加入" かつ 契約商品.紐づけ元契約商品 が null の場合
        if(ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '加入' &&
           ci.CMN_LinkedSourceContractItem__c == null){
            //QCIS電力契約.合算請求ID = 支払情報.合算請求ID
            mapping.put('C_SummaryInvoiceID__c', convertNull(ci.CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c));            // 合算請求ID
        }
        mapping.put('C_InvoiceMethod__c', convertNull(invoiceMethod));                                                   // 請求方式
        // 請求方式・一時退避用変更後請求方式
        // 契約商品.合算請求マスタ更新区分 が "脱退→新規" 又は "脱退→加入" かつ 契約商品.紐づけ元契約商品 が null の場合
        if((ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→新規' ||
            ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入') &&
            ci.CMN_LinkedSourceContractItem__c == null){
            mapping.put('C_InvoiceMethod__c', convertNull(invoiceMethodHistory));                                        // 請求方式
            mapping.put('C_InvoiceMethodForChange__c', convertNull(invoiceMethod));                                      // 一時退避用変更後請求方式
        }
        mapping.put('C_BillingDetailNoDisplayFlg__c', convertNull(billingDetailNoDisplayFlg));                           // 請求明細非表示フラグ
        mapping.put('C_PaymentCondition__c', convertNull(paymentCondition));                                             // 支払条件
        // 一時退避用合算請求ID
        // 契約商品.合算請求マスタ更新区分 が "脱退→加入" かつ 契約商品.紐づけ元契約商品 が null の場合
        if(ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入' &&
           ci.CMN_LinkedSourceContractItem__c == null){

            //QCIS電力契約.一時退避用合算請求ID = 支払情報.合算請求ID
            mapping.put('C_SummaryInvoiceIDForChange__c', convertNull(ci.CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c));   // 一時退避用合算請求ID
        }

        // マッピング（新規の場合）
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C) {
            mapping.put('C_CompleteGS__c', '"Temporary"');                                              // 登録ステータス
            mapping.put('dcis2__StartRequestDate__c', 'null');                                          // 使用開始希望日
            mapping.put('C_ContractUpdateDate__c', 'null');                                             // 契約更新日
            mapping.put('dcis2__InhouseStatusGS__c', '"ContractCompleted"');                            // 業務状況
            mapping.put('dcis2__EntryStatusGS__c', '"5"');                                              // 申込状況
            mapping.put('dcis2__ContractClassification__c', '"高圧"');                                  // 契約種別
            mapping.put('dcis2__ContractSupplyTypeGS__c', '"All"');                                     // 契約供給形態
            mapping.put('dcis2__ContractApplicationTypeGS__c', '"StartContract"');                      // 契約申込種別
            mapping.put('dcis2__ContactInfoEqualSupplyPoint__c', '"false"');                            // ご連絡先は供給地点と同じとする
            mapping.put('dcis2__ContactTypeGS__c', '"0"');                                              // ご連絡先区分
            mapping.put('C_CalcHoldFlg__c', '"false"');                                                 // 料金計算保留フラグ
            // 2026/04/03 「PRICE_REVISION_2025-2082 請求連携補正フラグ（C_CorrectionFlag__c）への連携廃止」 平松 Delete
            // mapping.put('C_CorrectionFlag__c', '"false"');                                              // 請求連携補正フラグ
            mapping.put('C_IndividualInvoiceFlg__c', '"true"');                                         // 個別請求フラグ
            mapping.put('dcis2__ContractAutoUpdateFlg__c', '"false"');                                  // 契約自動更新対象
            mapping.put('C_ReservePowerExistence__c', '"なし"');                                        // 予備電力（予備線・予備電源）の有無
            //ARVE-5331start 新規時のみマッピングする項目に変更
            mapping.put('dcis2__NextMaterReadingDate__c', convertNull(ci.CMN_NextMaterReadingDate__c)); // 次回検針日
            mapping.put('dcis2__Member__c', convertNull(accId));                                        // 会員
            mapping.put('dcis2__BillingToAccount__c', convertNull(accId));                              // 請求名寄せ取引先
            //ARVE-5331end
        }else if(ci.CMN_OrderItem__r.CMN_TypeDetail__c == '契約情報補正'){
            mapping.put('C_CompleteGS__c', '"Temporary"');                                              // 登録ステータス
        }

        // マッピング（複製廃止の場合）
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_D && 
           ci.CMN_ReproduceContractItem__c != null){
            mapping.put('dcis2__ContractEndDate__c', convertNull(ci.CMN_ContractEndDate__c));           // 契約終了日

        // マッピング（契約更改の場合）
        }else if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C && 
                 ci.CMN_OrderItem__c != null &&
                 ci.CMN_OrderItem__r.CMN_TypeDetail__c == '契約更改' &&
                 ci.CMN_OldContractItem__c != null){
            String prevRecId = qcisCntrMap.get(ci.CMN_OldContractItem__r.CMN_QCISContractId__c)?.Id;
            mapping.put('dcis2__PreviousContract__c', convertNull(prevRecId));                          // 以前の電力契約
            mapping.put('C_ContinuedUseMigrationStatus__c', '"NotMigrated"');                           // 継続利用契約データ移行状況
            mapping.put('C_ContinuedUseContract__c', convertNull(prevRecId));                           // 継続利用契約番号

        // マッピング（複製追加の場合）
        }else if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C && 
                 ci.CMN_DeleteContractItem__c != null){
            String prevRecId = qcisCntrMap.get(ci.CMN_DeleteContractItem__r.CMN_QCISContractId__c)?.Id;
            mapping.put('dcis2__PreviousContract__c', convertNull(prevRecId));                          // 以前の電力契約
            // QuickCIS契約番号の継続利用対象の場合
            if (ci.CMN_ContinuedUseFlg__c) {
                mapping.put('C_ContinuedUseMigrationStatus__c', '"NotMigrated"');                       // 継続利用契約データ移行状況
                mapping.put('C_ContinuedUseContract__c', convertNull(prevRecId));                       // 継続利用契約番号
            }

        // マッピング（供給廃止の場合）
        }else if(ci.CMN_LinkageKbn__c == LINKAGEKBN_D && 
                 ci.CMN_ReproduceContractItem__c == null &&
                 ci.CMN_DeleteContractItem__c == null){
            mapping.put('dcis2__ContractEndDate__c', convertNull(ci.CMN_ContractEndDate__c));           // 契約終了日
            mapping.put('dcis2__FinalContractEndDate__c', convertNull(ci.CMN_ContractEndDate__c));      // 最終契約終了日
            mapping.put('dcis2__EntryStatusGS__c', '"9"');                                              // 申込状況(契約廃止完了)
            mapping.put('dcis2__InhouseStatusGS__c', '"AbolitionCompleted"');                           // 業務状況(契約廃止完了)
            mapping.put('C_OriginalContractEndDate__c', convertNull(originalContractEndDate));          // 元契約終了日
        }

        return mapping;
    }


    /**
     * QuickCIS※電力契約の更新用マッピングデータを生成（子契約）
     * @param ci ARVE契約商品
     * @param qcisCntr ※電力契約（親）
     * @return Map<String, String> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update Start

    //private Map<String, String> mappingContractChild(
        //CMN_ContractItem__c ci, CMN_QuickCISRecord qcisCntr) {
    private Map<String, String> mappingContractChild(
        CMN_ContractItem__c ci, Map<String, CMN_QuickCISRecord> qcisCntrMap) {
        // 2026/02/21 「PRICE_REVISION_2025-1547 追加要件①」 坂寄 Delete Start
        // 紐づけ元契約商品.QuickCIS契約番号
        // String qcisCntrParentId = ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c;
        // ※電力契約（親）
        // CMN_QuickCISRecord qcisCntr = qcisCntrMap.get(qcisCntrParentId);
        // 2026/02/21 「PRICE_REVISION_2025-1547 追加要件①」 坂寄 Delete End

        // 2026/02/20 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
        CMN_QuickCISRecord qcisCntr = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c);
        // マッピング（継続利用の複製廃止の場合）
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_D 
           && ci.CMN_LinkedSourceContractItem__c != null 
           && ci.CMN_ContinuedUseFlg__c
           && ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__c != null
        ){
            // 紐づけ元契約商品.複製契約商品.QuickCIS契約番号（複製後）に対応する電力契約.継続利用契約データ移行状況が「移行完了」か             
            String reproducedQCISContractSts = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c)?.ContinuedUseMigrationStatus;
            //主契約の後から連携した場合、紐づけ元契約商品.複製契約商品.QuickCIS契約番号（複製後）を設定
            if(reproducedQCISContractSts == 'Migrated'){
                //電力契約               
                qcisCntr = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c);
                //主契約と同時に連携した場合(移行状況が「未移行」)、「紐づけ元契約商品.複製契約商品.QuickCIS契約番号」を設定
            }else{
                //電力契約
                qcisCntr = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_QCISContractId__c); 
            }          

        // マッピング（それ以外の複製契約に紐づく付帯 または 複製契約に紐づかない付帯の場合）
        }else if(ci.CMN_LinkedSourceContractItem__c != null){
            
            //付帯契約の場合(契約商品.紐づけ元契約商品が空ではない)
            //紐づけ元契約商品.QuickCIS契約番号（複製後）に対応する電力契約.継続利用契約データ移行状況が「移行完了」か 
            String reproducedQCISContractSts = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproducedQCISContractId__c)?.ContinuedUseMigrationStatus;
            //主契約の後から連携した場合、「紐づけ元契約商品（主契約）.QuickCIS契約番号」を設定
            if(reproducedQCISContractSts == null || reproducedQCISContractSts == 'Migrated'){
                //電力契約              
                qcisCntr = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c);
            //主契約と同時に連携した場合、「紐づけ元契約商品（主契約）.QuickCIS契約番号（複製後）」を設定
            }else{
                //電力契約
                qcisCntr = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproducedQCISContractId__c);                
            } 
        }        

        // 2026/02/20 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End            
         // ※電力契約（親）が取得できなかった場合、連携エラーにして処理をスキップ
        if(qcisCntr == null) {
            ci.CMN_LinkSts__c = LINKSTS_ERR;
            ci.CMN_LinkErrorDetail__c = LINKERRORDETAIL_NOQCISPARENT;
            return new Map<String, String>();
        }
        // 2026/02/13 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update End

        // マッピング格納用マップ  Map<項目名, 値>
        Map<String, String> mapping = new Map<String, String>();

        // ARVE契約商品.商品ID
        String stockKeepingUnit = ci.CMN_StockKeepingUnit__c;
        if(Test.isRunningTest()) {
            stockKeepingUnit = stockKeepingUnit.removeEnd('UNIT');
        }
        // 予備電力（予備線・予備電源）フラグ
        Boolean yobiFlg = false;
        // アンシェラリーサービスフラグ
        Boolean AncillaryFlg = False;

        // 予備電力（予備線・予備電源）の有無・異容量フラグ設定の準備
        // ・qcisCntrにマッピング値を設定し、qcisCntr上で値を判定する
        // 契約商品.商品IDが「予備電力（予備線）」の場合
        if(stockKeepingUnit == 'P0108013W') {
            yobiFlg = true;
            qcisCntr.ReserveHighVCharge = ci.CMN_PowerContract__c; // 予備線契約電力(kW)
            qcisCntr.ReserveLineBaseContractCapacity = ci.CMN_ReserveSupplyCapacity__c; // 予備線契約時容量
        // 契約商品.商品IDが「予備電力（予備電源）」の場合
        }else if(stockKeepingUnit == 'P0108013X') {
            yobiFlg = true;
            qcisCntr.StandbyPowerCharge = ci.CMN_PowerContract__c; // 予備電源契約電力(kW)
            qcisCntr.ReservePowerContractCapacity = ci.CMN_ReservePowerCapacity__c; // 予備電源契約時容量
        // 契約商品.商品IDが「予備電力（第二予備電源）」の場合
        }else if(stockKeepingUnit == 'P0108015V') {
            yobiFlg = true;
            qcisCntr.StandbyPowerChargeSecond = ci.CMN_PowerContract__c; // 予備電源契約電力(kW)
            qcisCntr.ReservePowerContractCapacitySecond = ci.CMN_ReservePowerCapacity__c; // 予備電源契約時容量
        // 契約商品.商品IDが「アンシェラリー料金」）」の場合　※アンシラリーサービス
        }else if (stockKeepingUnit == 'P0108015M'){
            AncillaryFlg = true;
        }

        // 契約商品.商品IDが「予備電力（予備線）」「予備電力（予備電源）」「予備電力（第二予備電源）」の場合のみ予備電力のマッピング処理を実施
        if(yobiFlg) {
            // 予備電力（予備線・予備電源）の有無
            String reservePowerExistence = 'なし';
            if(qcisCntr.ReserveHighVCharge != null || qcisCntr.StandbyPowerCharge != null || qcisCntr.StandbyPowerChargeSecond != null) {
                // 「予備線契約電力(kW)」「予備電源契約電力(kW)」「第二予備電源契約電力(kW)」いずれかに値がある場合、"あり"を設定する
                reservePowerExistence = 'あり';
            }
            // 異容量フラグ
            Boolean dcsRequestFlg = false;
            // 以下のいずれかに該当する場合はTRUE
            //・「電力契約.予備線契約電力(kW)」に値があり「紐づけ元契約商品.契約電力（kW）」と「電力契約.予備線契約時容量」が異なる       
            //・「電力契約.予備電源契約電力(kW)」に値があり「紐づけ元契約商品.契約電力（kW）」と「電力契約.予備電源契約時容量」が異なる
            //・「電力契約.第二予備電源契約電力(kW)」に値があり「紐づけ元契約商品.契約電力（kW）」と「電力契約.第二予備電源契約時容量」が異なる
            if((qcisCntr.ReserveHighVCharge != null
                    && ci.CMN_LinkedSourceContractItem__r.CMN_PowerContract__c != qcisCntr.ReserveLineBaseContractCapacity)
                || (qcisCntr.StandbyPowerCharge != null 
                    && ci.CMN_LinkedSourceContractItem__r.CMN_PowerContract__c != qcisCntr.ReservePowerContractCapacity)
                || (qcisCntr.StandbyPowerChargeSecond != null 
                    && ci.CMN_LinkedSourceContractItem__r.CMN_PowerContract__c != qcisCntr.ReservePowerContractCapacitySecond)) {
                dcsRequestFlg = true;
            }

            // マッピング
            mapping.put('Id', convertNull(qcisCntr.Id));                                         // ID
            mapping.put('C_ReservePowerExistence__c', convertNull(reservePowerExistence));       // 予備電力（予備線・予備電源）の有無
            mapping.put('C_DifferentCapacitySpareRequestFlg__c', String.valueOf(dcsRequestFlg)); // 異容量フラグ
            // 契約商品.商品IDが「予備電力（予備線）」の場合
            if(stockKeepingUnit == 'P0108013W') {
                mapping.put('dcis2__ReserveHighVCharge__c', convertNull(ci.CMN_PowerContract__c));                 // 予備線契約電力(kW)
                mapping.put('C_ReserveLineBaseContractCapacity__c', convertNull(ci.CMN_ReserveSupplyCapacity__c)); // 予備線契約時容量
                mapping.put('C_ReserveSupplyVoltage__c', convertNull(ci.CMN_SupplyVoltage__c));                    // 予備線供給電圧
            // 契約商品.商品IDが「予備電力（予備電源）」の場合
            }else if(stockKeepingUnit == 'P0108013X') {
                mapping.put('dcis2__StandbyPowerCharge__c', convertNull(ci.CMN_PowerContract__c));                                  // 予備電源契約電力(kW)
                mapping.put('C_ReservePowerContractCapacity__c', convertNull(ci.CMN_ReservePowerCapacity__c));                      // 予備電源契約時容量
                mapping.put('C_ReservePowerSupplyVoltage__c', convertNull(ci.CMN_SupplyVoltage__c));                                // 予備電源供給電圧
                mapping.put('C_StandbyPowerDiffVoltageFlg__c', String.valueOf(ci.CMN_DifferentSupplyVoltageFlg__c));                // 予備電源異電圧フラグ
                mapping.put('C_StandbyPowerInstrumentNumber__c', convertNull(ci.CMN_InstrumentsId__c));                             // 予備電源計器識別番号
                mapping.put('C_StandbyPowerInstrumentNumberPrev__c', convertNull(ci.CMN_BeforeReplacementInstrumentsId__c));        // 予備電源計器識別番号（取替前番号）
            // 契約商品.商品IDが「第二予備電力（予備電源）」の場合
            }else if(stockKeepingUnit == 'P0108015V') {
                mapping.put('C_StandbyPowerChargeSecond__c', convertNull(ci.CMN_PowerContract__c));                                 // 第二予備電源契約電力(kW)
                mapping.put('C_ReservePowerContractCapacitySecond__c', convertNull(ci.CMN_ReservePowerCapacity__c));                // 第二予備電源契約時容量
                mapping.put('C_ReservePowerSupplyVoltageSecond__c', convertNull(ci.CMN_SupplyVoltage__c));                          // 第二予備電源供給電圧
                mapping.put('C_StandbyPowerDiffVoltageFlgSecond__c', String.valueOf(ci.CMN_DifferentSupplyVoltageFlg__c));          // 第二予備電源異電圧フラグ
                mapping.put('C_StandbyPowerInstrumentNumberSecond__c', convertNull(ci.CMN_InstrumentsId__c));                       // 第二予備電源計器識別番号
                mapping.put('C_StandbyPowerInstrumentNumberSecondPrev__c', convertNull(ci.CMN_BeforeReplacementInstrumentsId__c));  // 第二予備電源計器識別番号（取替前番号）
            }
        // 契約商品.商品IDが「アンシェラリー料金」）」の場合のみアンシラリーサービスのマッピングを実施
        }else if(AncillaryFlg){
            // マッピング
            mapping.put('Id', convertNull(qcisCntr.Id));            // ID
            mapping.put('C_AncillaryServiceCapacity__c', convertNull(ci.CMN_PowerContract__c)); // アンシラリーサービス料金契約容量(kW）
        }
        return mapping;
    }

    /**
     * QuickCIS※電力契約の作成・更新用マッピングデータを生成（分割先）
     * @param ci ARVE契約商品
     * @param cntrRtMap QuickCIS※電力契約レコードタイプマップ
     * @param qcisAccMap QuickCIS取引先マップ（分割元）
     * @param qcisCntrMap QuickCIS※電力契約マップ
     * @param qcisChargeMenuMap ※料金メニューマップ
     * @param divSeqNum 連番値
     * @return Map<String, String> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private Map<String, String> mappingContractDivision(
        CMN_ContractItem__c ci, Map<String, String> cntrRtMap, Map<String, CMN_QuickCISRecord> qcisAccMap,
        Map<String, CMN_QuickCISRecord> qcisCntrMap, Map<String, String> qcisChargeMenuMap, Decimal divSeqNum, CMN_PaymentInfo__c pilh) {

        // マッピング格納用マップ  Map<項目名, 値>
        Map<String, String> mapping = new Map<String, String>();
        // マッピング置換用マップ
        Map<String, Map<String, String>> valPattern = this.mapValPattern.get('mappingContract');

        // レコードID
        // QuickCIS契約番号に合致するQuickCIS電力契約が存在する場合はそのID、しない場合はnull
        String recId = qcisCntrMap.get(ci.CMN_QCISContractId__c)?.Id;
        // QuickCIS契約番号の継続利用対象の複製契約の場合はIdを空で連携
        if(ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_C){
            recId = null;
        }
        // QuickCIS電力契約が存在する場合、ダブルクォーテーションで囲む
        if(recId != null) {
            recId = '"' + recId + '"';
        }

        // 会員ID（※CISお客様番号がARVE契約商品.分割元契約商品.見える化まとめコードと等しいQuickCIS取引先のID）
        String accId = qcisAccMap.get(ci.CMN_DivisionSource__r.CMN_VisualizationCustomerNum__c)?.Id;

        // 商品ID
        String stockKeepingUnit = ci.CMN_StockKeepingUnit__c;
        if(Test.isRunningTest()) {
            stockKeepingUnit = stockKeepingUnit.removeEnd('UNIT');
        }
        // 料金メニュー名（商品ID + 供給地点特定番号（上2桁） + 単価情報）
        String chargeMenuName = stockKeepingUnit
                                + ci.CMN_DivisionSource__r.CMN_SupplyPointSpecificNum__c?.left(2)
                                + ci.CMN_UnitPriceKbn__c?.left(4);
        // カスタムメタデータ型「料金メニュー」
        CMN_QuickCISChargeMenu_Setting__mdt chargeMenuSetting = CMN_QuickCISChargeMenu_Setting__mdt.getInstance(chargeMenuName);
        // 料金メニューID
        String chargeMenu = qcisChargeMenuMap.get(chargeMenuSetting?.CMN_ChargeMenu__c);
        if(chargeMenu != null) {
            chargeMenu = '"' + chargeMenu + '"';
        }
        // 使用調整項単価
        String adjustedUnitPrice = chargeMenuSetting?.CMN_AdjustedUnitPrice__c;
        // 使用調整項単価（ピーク）
        String adjustedUnitPriceForPeak = chargeMenuSetting?.CMN_AdjustedUnitPriceForPeak__c;
        // ベースロード料金メニュー  SFID
        String baseLoadInvoiceMenu = qcisChargeMenuMap.get(chargeMenuSetting?.CMN_BaseLoadInvoiceMenu__c);
        if(baseLoadInvoiceMenu != null) {
            baseLoadInvoiceMenu = '"' + baseLoadInvoiceMenu + '"';
        }
        // ピークロード料金メニューSFID
        String peakLoadInvoiceMenu = qcisChargeMenuMap.get(chargeMenuSetting?.CMN_PeakLoadInvoiceMenu__c);
        if(peakLoadInvoiceMenu != null) {
            peakLoadInvoiceMenu = '"' + peakLoadInvoiceMenu + '"';
        }

        // マッピング用変数
        // 業務用/産業用区分
        String industryKbn = valPattern.get('industryKbn').get(ci.CMN_IndustryKbn__c);
        // 大口フラグ
        String largeCustomerFlg = valPattern.get('largeCustomerFlg').get(String.valueOf(ci.CMN_LargeCustomerFlg__c)); 
        // 契約開始日
        Date contractStartDate = ci.CMN_ContractStartDate__c;
        // 需給開始希望月
        String supplyDemandStartDate;
        if(ci.CMN_SupplyDemandStartDate__c != null) {
            Date sdsDate = ci.CMN_SupplyDemandStartDate__c;
            supplyDemandStartDate = String.valueOf(sdsDate.year()) + String.valueOf(sdsDate.month()).leftPad(2, '0');
        }
        // 業務種別
        String businessTypeGS = valPattern.get('businessTypeGS').get(ci.CMN_BusinessType__c);
        // 業務種別（ラベル）
        String businessTypeLabel = valPattern.get('businessTypeLabel').get(ci.CMN_BusinessType__c);
        // 最低引取電力量算出単価時間
        Integer loadFactor;
        if(ci.CMN_UnitPriceKbn__c == '2024年度単価') {
            for(String sku : valPattern.get('loadFactor').keySet()) {
                if(sku.contains(stockKeepingUnit)) {
                    loadFactor = Integer.valueOf(valPattern.get('loadFactor').get(sku));
                }
            }
        }
        // 検針区分
        String powerAmountMeasuringTypeGS = valPattern.get('powerAmountMeasuringTypeGS').get(ci.CMN_PowerAmountMeasuringType__c);
        // 計量日（高圧）
        Integer highVAcutualMaterReadingDate;
        if(!String.isBlank(ci.CMN_AcutualMaterReadingDate__c)) {
            highVAcutualMaterReadingDate = Integer.valueOf(ci.CMN_AcutualMaterReadingDate__c);
        }
        // 契約電力決定方式
        String powerContractProcessGS = valPattern.get('powerContractProcessGS').get(ci.CMN_PowerContractProcess__c);
        // 契約決定方法
        String determineConnectionMethodGS = valPattern.get('determineConnectionMethodGS').get(ci.CMN_PowerContractProcess__c);
        // 契約電圧区分
        String contactVoltageDiv;
        Decimal supplyVoltage = ci.CMN_SupplyVoltage__c;
        if(3000 <= supplyVoltage && supplyVoltage <= 6000) {
            contactVoltageDiv = '1';
        }else if(10000 <= supplyVoltage && supplyVoltage <= 30000) {
            contactVoltageDiv = '2';
        }else if(supplyVoltage == 60000) {
            contactVoltageDiv = '3';
        }else if(60000 < supplyVoltage && supplyVoltage <= 140000) {
            contactVoltageDiv = '4';
        }else if(supplyVoltage == 275000) {
            contactVoltageDiv = '5';
        }
        // 契約電力ランク
        String powerContractRank = '未満'; 
        if(businessTypeGS == '2' && 500 <= ci.CMN_PowerContract__c) {
                powerContractRank = '以上';
        }else if(businessTypeGS == '3') {
            powerContractRank = '特高';
        }
        /** 20260306 USE DEL
        // EP電力区分
        String ePPowerDiv;
        if(!String.isBlank(powerAmountMeasuringTypeGS) && !String.isBlank(ci.CMN_UnitPriceKbn__c)) {
            // マッピングキー
            String ePPowerDivKey = 'ePPowerDiv' + powerAmountMeasuringTypeGS + '_' + ci.CMN_UnitPriceKbn__c.left(4);
            // マッピングから値を取得
            ePPowerDiv = valPattern.get(ePPowerDivKey).get(powerContractRank);
        }
        */
        // 需要者(発電者)窓口連絡先氏名
        String customerCounterName = (ci.CMN_BillingLastName__c ?? '')
                                    + (ci.CMN_BillingFirstName__c ?? '');
        // ご連絡先電話番号
        String[] contactPhone = new String[3];
        if(!String.isBlank(ci.CMN_BillingTellPhone__c)) {
            contactPhone = ci.CMN_BillingTellPhone__c.split('-');
            if(contactPhone.size() != 3) {
                contactPhone = new String[3];
            }
        }
        // ご連絡先電話番号区分
        String contactPhoneClassificationGS = valPattern.get('contactPhoneClassificationGS').get(ci.CMN_BillingPhoneKbn1__c);
        // ご連絡先都道府県
        String contactPrefNameGS;
        if(!String.isBlank(ci.CMN_BillingStateCode__c)) {
            contactPrefNameGS = String.valueOf(Integer.valueOf(ci.CMN_BillingStateCode__c));
        }
        // ご連絡先丁目番地
        String contactStreetName = (ci.CMN_BillingSection__c ?? '')
                                    + (ci.CMN_BillingBlock1__c ?? '')
                                    + (ci.CMN_BillingBlock2__c ?? '')
                                    + (ci.CMN_BillingBlock3__c ?? '');
        // 契約場所_第一連絡先
        String[] dlTellPhone = new String[3];
        if(ci.CMN_DemandLocationTellPhone__c != null) {
            dlTellPhone = ci.CMN_DemandLocationTellPhone__c.split('-');
            if(dlTellPhone.size() != 3) {
                dlTellPhone = new String[3];
            }
        }
        // 需要者(発電者)電話番号区分1
        String customerPhoneClassification1GS = valPattern.get('customerPhoneClassification1GS').get(ci.CMN_DemandLocationPhoneKbn1__c);
        // 契約場所_第二連絡先
        String[] dlMobilePhone = new String[3];
        if(ci.CMN_DemandLocationMobilePhone__c != null) {
            dlMobilePhone = ci.CMN_DemandLocationMobilePhone__c.split('-');
            if(dlMobilePhone.size() != 3) {
                dlMobilePhone = new String[3];
            }
        }
        // 需要者(発電者)電話番号区分2
        String customerPhoneClassification2GS = valPattern.get('customerPhoneClassification2GS').get(ci.CMN_DemandLocationPhoneKbn2__c);
        // 需要者(発電者)丁目番地
        String customerStreetName = (ci.CMN_DemandLocationSection__c ?? '')
                                    + (ci.CMN_DemandLocationBlock1__c ?? '')
                                    + (ci.CMN_DemandLocationBlock2__c ?? '')
                                    + (ci.CMN_DemandLocationBlock3__c ?? '');
        // 需要者(発電者)都道府県
        String customerPrefNameGS;
        if(!String.isBlank(ci.CMN_DemandLocationStateCode__c)) {
            // 0埋め2桁 -> 0埋めなしの1桁に変換
            customerPrefNameGS = String.valueOf(Integer.valueOf(ci.CMN_DemandLocationStateCode__c));
        }
        // 企業特約グループ番号
        String specialAgreementGroupNo;
        if(ci.CMN_UnitPriceKbn__c == '2024年度単価') {
            specialAgreementGroupNo = ci.CMN_SpecialAgreementGroupNo__c;
        }
        // 再エネ減免率適用期間（開始年月）
        Integer renewableEnergiesExemptionRateStart;
        if(!String.isBlank(ci.CMN_RenewableEnergiesStartPeriod__c)) {
            renewableEnergiesExemptionRateStart = Integer.valueOf(ci.CMN_RenewableEnergiesStartPeriod__c);
        }
        // 再エネ減免率適用期間（終了年月）
        Integer renewableEnergiesExemptionRateEnd;
        if(!String.isBlank(ci.CMN_RenewableEnergiesEndPeriod__c)) {
            renewableEnergiesExemptionRateEnd = Integer.valueOf(ci.CMN_RenewableEnergiesEndPeriod__c);
        }
        // 合算請求締め日
        String summaryInvoiceClosingDate;
        if(!ci.CMN_DivisionBillingFlg__c && !String.isBlank(ci.CMN_PaymentInfo__r?.CMN_CombinedBillingDeadline__c)) {
            summaryInvoiceClosingDate = ci.CMN_PaymentInfo__r.CMN_CombinedBillingDeadline__c.left(2);
        }
        // 支払期限プラス日数（暦日）
        Integer paymentDueDatePlusCalendarDays;
        if(!String.isBlank(ci.CMN_PayDeadlinePlusDays__c)) {
            paymentDueDatePlusCalendarDays = Integer.valueOf(ci.CMN_PayDeadlinePlusDays__c);
        }
        // 延滞利息端数処理位置
        String latePaymentInterestPos = valPattern.get('latePaymentInterestPos').get(ci.CMN_LateInterestRoundPosition__c);
        // 延滞利息端数処理方法
        String latePaymentInterestMethod = valPattern.get('latePaymentInterestMethod').get(ci.CMN_LateInterestRoundMethod__c);
        // 分割数
        Integer splitCount;
        if(!String.isBlank(ci.CMN_DivisionNum__c)) {
            splitCount = Integer.valueOf(ci.CMN_DivisionNum__c);
        }
        // 分割時割合
        Decimal splitPercentageAmount;
        if(!String.isBlank(ci.CMN_DivisionRate__c)) {
            splitPercentageAmount = Decimal.valueOf(ci.CMN_DivisionRate__c);
        }
        // 指定月請求作成年月
        Integer specifiedMonthBillingCreationYearMonth;
        if(!String.isBlank(ci.CMN_SpecifiedMonthBillCreateDate__c)) {
            specifiedMonthBillingCreationYearMonth = Integer.valueOf(ci.CMN_SpecifiedMonthBillCreateDate__c);
        }
        // 前契約開始日
        Date prevContractStartDate = ci.CMN_OldJuyobasho__r?.ARV_ContractStart__c;
        prevContractStartDate = prevContractStartDate ?? ci.CMN_OldContractItem__r.CMN_ContractStartDate__c;
        // 前契約終了日
        Date prevContractEndDate = ci.CMN_OldJuyobasho__r?.ARV_ContractEnd__c;
        prevContractStartDate = prevContractStartDate ?? ci.CMN_OldContractItem__r.CMN_ContractEndDate__c;
        // 通知方法
        String alertNotifierTypeGS;
        if(ci.CMN_NotificationMethod__c == '郵送') {
            alertNotifierTypeGS = valPattern.get('alertNotifierTypeGS').get(ci.CMN_MailingContents__c);
        } else if(ci.CMN_NotificationMethod__c == 'ポータル') {
            alertNotifierTypeGS = valPattern.get('alertNotifierTypeGS').get('ポータル');
        }
        // 災害特措区分
        String specialDisasterClass = valPattern.get('specialDisasterClass').get(ci.CMN_DisasterMeasureKbn__c);
        // 支払方法
        String billingMethod = valPattern.get('billingMethod').get(ci.CMN_PaymentInfo__r.CMN_PaymentMethod__c);
        // 口座振替方法
        String accountTransfer = valPattern.get('accountTransfer').get(ci.CMN_PaymentInfo__r.CMN_BankAccTransferMethod__c);
        // 口座照合ステータス
        String accountRequestStatus = valPattern.get('accountRequestStatus').get(ci.CMN_PaymentInfo__r.CMN_BankAccMatchSts__c);
        // 預金種別
        String depositType = valPattern.get('depositType').get(ci.CMN_PaymentInfo__r.CMN_DepositType__c);
        if(ci.CMN_PaymentInfo__r.CMN_FinancialInstName__c == 'ゆうちょ銀行') {
            depositType = ci.CMN_PaymentInfo__r.CMN_PassbookNumUpper1Digit__c;
        }
        // 振込詳細区分
        String directDepositKbn = valPattern.get('directDepositKbn').get(ci.CMN_PaymentInfo__r.CMN_TransferDetailKbn__c);
        // 請求方式
        String invoiceMethod = valPattern.get('invoiceMethod').get(ci.CMN_PaymentInfo__r.CMN_InvoiceMethod__c);
        // 支払情報（履歴）.請求方式
        String invoiceMethodHistory = (pilh != null && !String.isBlank(pilh.CMN_InvoiceMethod__c)) ? valPattern.get('invoiceMethod').get(pilh.CMN_InvoiceMethod__c) : null;
        // 請求明細非表示フラグ
        String billingDetailNoDisplayFlg = valPattern.get('billingDetailNoDisplayFlg').get(String.valueOf(ci.CMN_PaymentInfo__r.CMN_BillingDetailNoDisplayFlg__c));
        // 支払条件
        String paymentCondition = valPattern.get('paymentCondition').get(ci.CMN_PaymentInfo__r.CMN_PaymentCondition__c);

        // 合算請求マスタ更新区分
        String SummaryInvoiceUpdateGS = ci.CMN_SummaryInvoiceMasterUpdateKbn__c;
        // QCIS電力契約.合算請求ID = Null かつ 契約商品.合算請求マスタ更新区分 が "更新"の場合
        if(String.isBlank(qcisCntrMap.get(ci.CMN_QCISContractId__c)?.SummaryInvoiceID) &&
           ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '更新'){
            //QCIS電力契約.合算請求マスタ更新区分 = 新規
            SummaryInvoiceUpdateGS = '新規';
        }

        // 元契約終了日
        String originalContractEndDate = qcisCntrMap.get(ci.CMN_QCISContractId__c)?.ContractEndDate;

         // 口座名義カナ1
        String bankAccNameKana2 = getBankAccNameKana(ci);

        // 分割関連元電力契約
        String splitAssociatedContractId = qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c)?.Id;
        if(splitAssociatedContractId != null) {
            splitAssociatedContractId = '"' + splitAssociatedContractId + '"';
        }

        // マッピングC_ManageAccount__c
        mapping.put('Id', recId);  
        mapping.put('RecordTypeId', convertNull(cntrRtMap.get('MainHighV')));                                            // レコードタイプID
        mapping.put('C_IndustryKbn__c', convertNull(industryKbn));                                                       // 業務用/産業用区分
        mapping.put('C_LargeCustomerFlg__c', convertNull(largeCustomerFlg));                                             // 大口フラグ
        mapping.put('dcis2__ContractStartDate__c', convertNull(contractStartDate));                                      // 契約開始日
        mapping.put('C_SupplyDemandDesiredStartMonth__c', convertNull(supplyDemandStartDate));                           // 需給開始希望月
        mapping.put('dcis2__BusinessTypeGS__c', convertNull(businessTypeGS));                                            // 業務種別
        mapping.put('dcis2__BusinessTypeLabel__c', convertNull(businessTypeLabel));                                      // 業務種別（ラベル）
        mapping.put('dcis2__ChargeMenu__c', chargeMenu);                                                                 // 料金メニュー
        mapping.put('C_LoadFactor__c', convertNull(loadFactor));                                                         // 最低引取電力量算出単価時間
        mapping.put('C_AdjustedUnitPrice__c', convertNull(adjustedUnitPrice));                                           // 使用調整項単価
        mapping.put('C_AdjustedUnitPriceForPeak__c', convertNull(adjustedUnitPriceForPeak));                             // 使用調整項単価（ピーク）
        mapping.put('dcis2__PowerAmountMeasuringTypeGS__c', convertNull(powerAmountMeasuringTypeGS));                    // 検針区分
        mapping.put('C_HighVAcutualMaterReadingDate__c', convertNull(highVAcutualMaterReadingDate));                     // 計量日（高圧）
        mapping.put('dcis2__PowerContractProcessGS__c', convertNull(powerContractProcessGS));                            // 契約電力決定方法
        mapping.put('dcis2__DetermineConnectionMethodGS__c', convertNull(determineConnectionMethodGS));                  // 契約決定方法
        //ARVE-5331 更新・削除かつ実量制の時は契約電力は変更しない
        if(!(ci.CMN_LinkageKbn__c != LINKAGEKBN_C && ci.CMN_PowerContractProcess__c == 'ONDEMAND：実量制')) {
            mapping.put('dcis2__HighVPowerContract__c', convertNull(ci.CMN_PowerContract__c));                           // 高圧契約電力(kW)   
        }
        mapping.put('C_ContactVoltageDiv__c', convertNull(contactVoltageDiv));                                           // 契約電圧区分
        mapping.put('C_PowerContractRank__c', convertNull(powerContractRank));                                           // 契約電力ランク
        // 20260306 USE DEL
        // mapping.put('C_EPPowerDiv__c', convertNull(ePPowerDiv));                                                         // EP電力区分
        mapping.put('dcis2__CustomerCounterName__c', convertNull(customerCounterName));                                  // 需要者(発電者)窓口連絡先氏名
        mapping.put('dcis2__ContactPhoneAreaCode__c', convertNull(contactPhone[0]));                                     // ご連絡先電話番号(市外局番)
        mapping.put('dcis2__ContactPhoneCityCode__c', convertNull(contactPhone[1]));                                     // ご連絡先電話番号(市内局番)
        mapping.put('dcis2__ContactPhoneSubscriberNumber__c', convertNull(contactPhone[2]));                             // ご連絡先電話番号(加入者番号)
        mapping.put('dcis2__ContactPhoneClassificationGS__c', convertNull(contactPhoneClassificationGS));                // ご連絡先電話番号区分
        mapping.put('dcis2__ContactPrefNameGS__c', convertNull(contactPrefNameGS));                                      // ご連絡先都道府県
        mapping.put('dcis2__ContactStreetName__c', convertNull(contactStreetName));                                      // ご連絡先丁目番地
        mapping.put('dcis2__CustomerCounterPhoneAreaCode__c', convertNull(dlTellPhone[0]));                              // 需要者(発電者)窓口電話番号（市外局番）
        mapping.put('dcis2__CustomerCounterPhoneCityCode__c', convertNull(dlTellPhone[1]));                              // 需要者(発電者)窓口電話番号（市内局番）
        mapping.put('dcis2__CustomerCounterPhoneCityCodeCustomerCoun__c', convertNull(dlTellPhone[2]));                  // 需要者(発電者)窓口電話番号（加入者番号）
        mapping.put('dcis2__CustomerPhoneAreaCode1__c', convertNull(dlTellPhone[0]));                                    // 需要者(発電者)電話番号(市外局番)1
        mapping.put('dcis2__CustomerPhoneCityCode1__c', convertNull(dlTellPhone[1]));                                    // 需要者(発電者)電話番号(市内局番)1
        mapping.put('dcis2__CustomerPhoneSubscriberNumber1__c', convertNull(dlTellPhone[2]));                            // 需要者(発電者)電話番号(加入者番号)1
        mapping.put('dcis2__CustomerPhoneClassification1GS__c', convertNull(customerPhoneClassification1GS));            // 需要者(発電者)電話番号区分1
        mapping.put('dcis2__CustomerPhoneAreaCode2__c', convertNull(dlMobilePhone[0]));                                  // 需要者(発電者)電話番号(市外局番)2
        mapping.put('dcis2__CustomerPhoneCityCode2__c', convertNull(dlMobilePhone[1]));                                  // 需要者(発電者)電話番号(市内局番)2
        mapping.put('dcis2__CustomerPhoneSubscriberNumber2__c', convertNull(dlMobilePhone[2]));                          // 需要者(発電者)電話番号(加入者番号)2
        mapping.put('dcis2__CustomerPhoneClassification2GS__c', convertNull(customerPhoneClassification2GS));            // 需要者(発電者)電話番号区分2
        mapping.put('dcis2__CustomerPrefNameGS__c', convertNull(customerPrefNameGS));                                    // 需要者(発電者)都道府県
        mapping.put('dcis2__CustomerStreetName__c', convertNull(customerStreetName));                                    // 需要者(発電者)丁目番地
        mapping.put('C_SpecialAgreementGroupNo__c', convertNull(specialAgreementGroupNo));                               // 企業特約グループ番号
        mapping.put('C_RenewableEnergiesExemptionRateStart__c', convertNull(renewableEnergiesExemptionRateStart));       // 再エネ減免率適用期間（開始年月）
        mapping.put('C_RenewableEnergiesExemptionRateEnd__c', convertNull(renewableEnergiesExemptionRateEnd));           // 再エネ減免率適用期間（終了年月）
        mapping.put('C_BaseLoadInvoiceMenu__c', baseLoadInvoiceMenu);                                                    // ベースロード料金メニュー
        mapping.put('C_PeakLoadInvoiceMenu__c', peakLoadInvoiceMenu);                                                    // ピークロード料金メニュー
        mapping.put('C_SummaryInvoiceClosingDate__c', convertNull(summaryInvoiceClosingDate));                           // 合算請求締め日
        mapping.put('C_PaymentDueDatePlusCalendarDays__c', convertNull(paymentDueDatePlusCalendarDays));                 // 支払期限プラス日数（暦日）
        mapping.put('C_LatePaymentInterestPos__c', convertNull(latePaymentInterestPos));                                 // 延滞利息端数処理位置
        mapping.put('C_LatePaymentInterestMethod__c', convertNull(latePaymentInterestMethod));                           // 延滞利息端数処理方法
        mapping.put('C_SplitCount__c', convertNull(splitCount));                                                         // 分割数
        mapping.put('C_SplitPercentageAmount__c', convertNull(splitPercentageAmount));                                   // 分割時割合
        mapping.put('C_SpecifiedMonthBillingCreationYearMonth__c', convertNull(specifiedMonthBillingCreationYearMonth)); // 指定月請求作成年月
        mapping.put('C_PrevContractStartDate__c', convertNull(prevContractStartDate));                                   // 前契約開始日
        mapping.put('C_PrevContractEndDate__c', convertNull(prevContractEndDate));                                       // 前契約終了日
        mapping.put('C_AlertNotifierTypeGS__c', convertNull(alertNotifierTypeGS));                                       // 通知方法
        mapping.put('C_SpecialDisasterClass__c', convertNull(specialDisasterClass));                                     // 災害特措区分
        mapping.put('C_SummaryInvoiceUpdateGS__c', convertNull(SummaryInvoiceUpdateGS));                                 // 合算請求マスタ更新区分
        mapping.put('C_BillingMethod__c', convertNull(billingMethod));                                                   // 支払方法
        mapping.put('C_AccountTransfer__c', convertNull(accountTransfer));                                               // 口座振替方法
        mapping.put('C_AccountNameKana__c', convertNull(bankAccNameKana2));                                               // 口座名義カナ1※編集後の値
        mapping.put('C_AccountRequestStatus__c', convertNull(accountRequestStatus));                                     // 口座照合ステータス
        mapping.put('C_DepositType__c', convertNull(depositType));                                                       // 預金種別
        mapping.put('C_DirectDepositKbn__c', convertNull(directDepositKbn));                                             // 振込詳細区分
        mapping.put('C_SplitAssociatedContract__c', splitAssociatedContractId);                                          // 分割関連元電力契約

        // カスタムメタデータを基にマッピングする
        mapping = mpgCmnClass.mapContractToQuickCIS(ci, mapping, 'mappingContractDivision');

        // 合算請求ID
        // 契約商品.合算請求マスタ更新区分 が "加入" かつ 契約商品.紐づけ元契約商品 が null の場合
        if(ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '加入' &&
           ci.CMN_LinkedSourceContractItem__c == null){
            //QCIS電力契約.合算請求ID = 支払情報.合算請求ID
            mapping.put('C_SummaryInvoiceID__c', convertNull(ci.CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c));            // 合算請求ID
        }
        mapping.put('C_InvoiceMethod__c', convertNull(invoiceMethod));                                                   // 請求方式
        // 請求方式・一時退避用変更後請求方式
        // 契約商品.合算請求マスタ更新区分 が "脱退→新規" 又は "脱退→加入" かつ 契約商品.紐づけ元契約商品 が null の場合
        if((ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→新規' ||
            ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入') &&
            ci.CMN_LinkedSourceContractItem__c == null){
            mapping.put('C_InvoiceMethod__c', convertNull(invoiceMethodHistory));                                        // 請求方式
            mapping.put('C_InvoiceMethodForChange__c', convertNull(invoiceMethod));                                      // 一時退避用変更後請求方式
        }
        mapping.put('C_BillingDetailNoDisplayFlg__c', convertNull(billingDetailNoDisplayFlg));                           // 請求明細非表示フラグ
        mapping.put('C_PaymentCondition__c', convertNull(paymentCondition));                                             // 支払条件
        // 一時退避用合算請求ID
        // 契約商品.合算請求マスタ更新区分 が "脱退→加入" かつ 契約商品.紐づけ元契約商品 が null の場合
        if(ci.CMN_SummaryInvoiceMasterUpdateKbn__c == '脱退→加入' &&
           ci.CMN_LinkedSourceContractItem__c == null){

            //QCIS電力契約.一時退避用合算請求ID = 支払情報.合算請求ID
            mapping.put('C_SummaryInvoiceIDForChange__c', convertNull(ci.CMN_PaymentInfo__r.CMN_SummaryInvoiceID__c));   // 一時退避用合算請求ID
        }
        
        // マッピング（新規の場合）
        if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C) {
            // 旧お客様番号、見える化まとめお客さま番号、請求まとめお客さま番号
            String customerNum = ci.CMN_DivisionSource__r.CMN_QCISContractId__c.replace('-', '') + String.valueOf(divSeqNum.setScale(0)).leftPad(5, '0');
            // 請求まとめお客さま番号
            String invoiceCompileCustomerNo = ci.CMN_BillCustomerNum__c != null ? ci.CMN_BillCustomerNum__c : customerNum;
            // 供給地点特定番号
            String supplyPointSpecificNumber = ci.CMN_DivisionSource__r.CMN_SupplyPointSpecificNum__c?.left(2) + '9999' + customerNum;

            mapping.put('C_ViewCompileCustomerNo__c', convertNull(customerNum));                        // 見える化まとめお客さま番号
            mapping.put('C_InvoiceCompileCustomerNo__c', convertNull(invoiceCompileCustomerNo));        // 請求まとめお客さま番号
            mapping.put('dcis2__SupplyPointSpecificNumber__c', convertNull(supplyPointSpecificNumber)); // 供給(受電)地点特定番号
            mapping.put('C_OldCustomerNo__c', convertNull(customerNum));                                // 旧お客様番号
            mapping.put('C_CompleteGS__c', '"Temporary"');                                              // 登録ステータス
            mapping.put('dcis2__StartRequestDate__c', 'null');                                          // 使用開始希望日
            mapping.put('C_ContractUpdateDate__c', 'null');                                             // 契約更新日
            mapping.put('dcis2__InhouseStatusGS__c', '"ContractCompleted"');                            // 業務状況
            mapping.put('dcis2__EntryStatusGS__c', '"5"');                                              // 申込状況
            mapping.put('dcis2__ContractClassification__c', '"高圧"');                                  // 契約種別
            mapping.put('dcis2__ContractSupplyTypeGS__c', '"All"');                                     // 契約供給形態
            mapping.put('dcis2__ContractApplicationTypeGS__c', '"StartContract"');                      // 契約申込種別
            mapping.put('dcis2__ContactInfoEqualSupplyPoint__c', '"false"');                            // ご連絡先は供給地点と同じとする
            mapping.put('dcis2__ContactTypeGS__c', '"0"');                                              // ご連絡先区分
            mapping.put('C_CalcHoldFlg__c', '"false"');                                                 // 料金計算保留フラグ
            // 2026/04/03 「PRICE_REVISION_2025-2082 請求連携補正フラグ（C_CorrectionFlag__c）への連携廃止」 平松 Delete
            // mapping.put('C_CorrectionFlag__c', '"false"');                                              // 請求連携補正フラグ
            mapping.put('C_IndividualInvoiceFlg__c', '"true"');                                         // 個別請求フラグ
            mapping.put('dcis2__ContractAutoUpdateFlg__c', '"false"');                                  // 契約自動更新対象
            mapping.put('C_ReservePowerExistence__c', '"なし"');                                        // 予備電力（予備線・予備電源）の有無
            mapping.put('dcis2__NextMaterReadingDate__c', convertNull(ci.CMN_NextMaterReadingDate__c)); // 次回検針日
            mapping.put('dcis2__Member__c', convertNull(accId));                                        // 会員
            mapping.put('dcis2__BillingToAccount__c', convertNull(accId));                              // 請求名寄せ取引先
            mapping.put('C_BiztepNoticeStopFlg__c', '"true"');                                                               // 契約内容・更改通知抑制フラグ
            mapping.put('C_SASBiztepLinkPendingFlg__c', '"true"');                                                           // SAS/ビジTEP連携保留フラグ
        }else if(ci.CMN_OrderItem__r.CMN_TypeDetail__c == '契約情報補正'){
            mapping.put('C_CompleteGS__c', '"Temporary"');                                              // 登録ステータス
        }

        // マッピング（「分割元契約商品.複製契約商品」に値がある かつ「分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）」に値がある場合）
        if(ci.CMN_DivisionSource__c != null &&
           ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__c != null &&
           ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c != null
        ){
            // 「分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）」に対応する「電力契約.Id」をマッピング                             
            mapping.put('C_SplitAssociatedContract__c', convertNull(qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c)?.Id));
            
        // マッピング（「分割元契約商品.複製契約商品」に値がない または「分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）」に値がない場合）
        }else if(ci.CMN_DivisionSource__c != null &&
           (ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__c == null ||
           ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c == null)
        ){
            // 「分割元契約商品.QuickCIS契約番号（複製後）」に値がある場合
            if(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c != null){
                // 「分割元契約商品.連携処理区分」がCreateの場合
                if(ci.CMN_DivisionSource__r.CMN_LinkageKbn__c == LINKAGEKBN_C){
                    // 「分割先契約商品.継続利用フラグ」がTRUE かつ 「分割先契約商品.連携処理区分」がDelete
                    if(ci.CMN_ContinuedUseFlg__c && ci.CMN_LinkageKbn__c == LINKAGEKBN_D){
                        // 「分割元契約商品.QuickCIS契約番号（複製後）」に対応する「電力契約.Id」をマッピング                
                        mapping.put('C_SplitAssociatedContract__c', convertNull(qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c)?.Id));              
                    }else{
                        // 「分割元契約商品.QuickCIS契約番号」に対応する「電力契約.Id」をマッピング                
                        mapping.put('C_SplitAssociatedContract__c', convertNull(qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c)?.Id));  
                    }
                }else{
                    // 「分割元契約商品.QuickCIS契約番号」に対応する「電力契約.Id」をマッピング                
                    mapping.put('C_SplitAssociatedContract__c', convertNull(qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c)?.Id));  
                }
            // 「分割元契約商品.QuickCIS契約番号（複製後）」に値がない場合
            }else if(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c == null){
                // 「分割元契約商品.QuickCIS契約番号」に対応する「電力契約.Id」をマッピング                
                mapping.put('C_SplitAssociatedContract__c', convertNull(qcisCntrMap.get(ci.CMN_DivisionSource__r.CMN_QCISContractId__c)?.Id));  
            }
        }

        // マッピング（複製廃止の場合）
        if (ci.CMN_LinkageKbn__c == LINKAGEKBN_D && 
            ci.CMN_ReproduceContractItem__c != null &&
            ci.CMN_DivisionSource__c != null){
            mapping.put('dcis2__ContractEndDate__c', convertNull(ci.CMN_ContractEndDate__c));           // 契約終了日
        // マッピング（供給廃止の場合）
        } else if(ci.CMN_LinkageKbn__c == LINKAGEKBN_D && 
             ci.CMN_ReproduceContractItem__c == null &&
             ci.CMN_DeleteContractItem__c == null){
            mapping.put('dcis2__ContractEndDate__c', convertNull(ci.CMN_ContractEndDate__c));           // 契約終了日
            mapping.put('dcis2__FinalContractEndDate__c', convertNull(ci.CMN_ContractEndDate__c));      // 最終契約終了日
            mapping.put('dcis2__EntryStatusGS__c', '"9"');                                              // 申込状況(契約廃止完了)
            mapping.put('dcis2__InhouseStatusGS__c', '"AbolitionCompleted"');                           // 業務状況(契約廃止完了)
            mapping.put('C_OriginalContractEndDate__c', convertNull(originalContractEndDate));          // 元契約終了日
        
        // マッピング（契約更改の場合）
        }else if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C && 
                 ci.CMN_OrderItem__c != null &&
                 ci.CMN_OrderItem__r.CMN_TypeDetail__c == '契約更改' &&
                 ci.CMN_OldContractItem__c != null){
            String prevRecId = qcisCntrMap.get(ci.CMN_OldContractItem__r.CMN_QCISContractId__c)?.Id;
            mapping.put('dcis2__PreviousContract__c', convertNull(prevRecId));                          // 以前の電力契約
            mapping.put('C_ContinuedUseMigrationStatus__c', '"NotMigrated"');                           // 継続利用契約データ移行状況
            mapping.put('C_ContinuedUseContract__c', convertNull(prevRecId));                           // 継続利用契約番号

        // マッピング（複製追加の場合）
        }else if(ci.CMN_LinkageKbn__c == LINKAGEKBN_C && 
                 ci.CMN_DeleteContractItem__c != null){
            String prevRecId = qcisCntrMap.get(ci.CMN_DeleteContractItem__r.CMN_QCISContractId__c)?.Id;
            mapping.put('dcis2__PreviousContract__c', convertNull(prevRecId));                          // 以前の電力契約
            // QuickCIS契約番号の継続利用対象の場合
            if (ci.CMN_ContinuedUseFlg__c) {
                mapping.put('C_ContinuedUseMigrationStatus__c', '"NotMigrated"');                       // 継続利用契約データ移行状況
                mapping.put('C_ContinuedUseContract__c', convertNull(prevRecId));                       // 継続利用契約番号
            }
        }

        return mapping;
    }



    /**
     * QuickCIS設定料金アイテム（需要家別）マスタ（親）の作成用マッピングデータを生成
     * @param ci ARVE契約商品
     * @param qcisCntr QuickCIS※電力契約
     * @param qcisChargeMenuMap QuickCIS※料金メニューマップ
     * @return Map<String, Map<String, String>> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private Map<String, Map<String, String>> mappingAcctCiMst(
        CMN_ContractItem__c ci, CMN_QuickCISRecord qcisCntr, 
        Map<String, String> qcisChargeMenuMap) {

        // マッピング格納用マップ  Map<精査対象項目名（料金アイテム）, Map<項目名, 値>>
        Map<String, Map<String, String>> returnMapping = new Map<String, Map<String, String>>();
        // マッピング置換用マップ
        Map<String, String> valPatternAmowInfo = this.mapValPattern.get('mappingAcctCiMst').get('amowInfo');

        // 商品ID
        String stockKeepingUnit = ci.CMN_StockKeepingUnit__c;
        if(Test.isRunningTest()) {
            stockKeepingUnit = stockKeepingUnit.removeEnd('UNIT');
        }

        // 分割先の場合は分割元の供給地点特定番号を参照する
        String supplyPointSpecificNum = ci.CMN_DivisionSource__c == null ? ci.CMN_SupplyPointSpecificNum__c : ci.CMN_DivisionSource__r.CMN_SupplyPointSpecificNum__c;
        // 料金メニュー名（商品ID + 供給地点特定番号（上2桁） + 単価情報）
        String chargeMenuName = stockKeepingUnit
                                + supplyPointSpecificNum.left(2)
                                + ci.CMN_UnitPriceKbn__c?.left(4);
        // カスタムメタデータ型「料金メニュー」
        CMN_QuickCISChargeMenu_Setting__mdt chargeMenuSetting = CMN_QuickCISChargeMenu_Setting__mdt.getInstance(chargeMenuName);
        // 料金メニューID
        String qcisCmId = qcisChargeMenuMap.get(chargeMenuSetting.CMN_ChargeMenu__c);

        // 精査対象項目の数だけ設定料金アイテム（需要家別）マスタを作成する
        // 精査対象項目
        List<String> tgtFieldList = new List<String>{
            'CMN_BasicUnitPrice__c',                   // 基本料金単価
            'CMN_ElectricityUnitPrice__c',             // 電力量料金単価（円/kWh）
            'CMN_ElectricityUnitPriceMorning__c',      // 電力量料金単価（朝）（円/kWh）
            'CMN_ElectricityUnitPriceAfternoon__c',    // 電力量料金単価（昼）（円/kWh）
            'CMN_ElectricityUnitPriceEvening__c',      // 電力量料金単価（晩）（円/kWh）
            'CMN_ElectricityUnitPriceNightHoliday__c', // 電力量料金単価（夜・日曜/祝日）（円/kWh）
            'CMN_ElectricityUnitPricePeak__c',         // 電力量料金単価（ピーク）（円/kWh）
            'CMN_ElectricityUnitPriceSummerDay__c',    // 電力量料金単価（夏季昼間）（円/kWh）
            'CMN_ElectricityUnitPriceOtherDay__c',     // 電力量料金単価（他季昼間）（円/kWh）
            'CMN_ElectricityUnitPriceDaytime__c',      // 電力量料金単価（昼間）（円/kWh）
            'CMN_ElectricityUnitPriceNight__c',        // 電力量料金単価（夜間）（円/kWh）
            'CMN_ElectricityUnitPriceHoliday__c',      // 電力量料金単価（日曜/祝日）（円/kWh）
            'CMN_ElectricityUnitPriceSummer__c',       // 電力量料金単価（夏季）（円/kWh）
            'CMN_ElectricityUnitPriceOther__c'         // 電力量料金単価（その他季）（円/kWh）
        };

        // 精査対象項目単位でのループ処理
        for(String fieldName : tgtFieldList) {
            String amowInfo; // 付帯メニュー・窓情報名
            Decimal fieldVal = (Decimal)ci.get(fieldName); // 項目値
            // 
            if(fieldVal != null && fieldVal > 0) {
                // 付帯メニュー・窓情報名を取得
                amowInfo = valPatternAmowInfo.get(fieldName);
                // 基本料金単価の場合、契約電力値によって異なる付帯メニュー・窓情報名を取得
                if(fieldName == 'CMN_BasicUnitPrice__c') {
                    if(ci.CMN_PowerContract__c < 500) {
                        amowInfo = valPatternAmowInfo.get(fieldName + '_Under500');
                    }else {
                        amowInfo = valPatternAmowInfo.get(fieldName + '_Over500');
                    }
                }
                // ブレンド対象料金アイテム種別
                String blendingTargetPriceItemType;
                if(chargeMenuSetting != null && chargeMenuSetting.CMN_BlendingTarget__c) {
                    blendingTargetPriceItemType = this.mapValPattern.get('mappingAcctCiMst').get('blendingTargetPriceItemType').get(amowInfo);
                }

                // マッピング
                Map<String, String> mapping = new Map<String, String>();
                mapping.put('C_ChargeMenu__c', convertNull(qcisCmId));                                    // 料金メニュー
                mapping.put('C_AdditionalMenuOrWindowInformation__c', convertNull(amowInfo));             // 付帯メニュー・窓情報
                mapping.put('C_BlendingTargetPriceItemType__c',convertNull(blendingTargetPriceItemType)); // ブレンド対象料金アイテム種別
                mapping.put('C_IndividualUnitPrice__c', convertNull(String.valueOf(fieldVal)));           // 個別単価
                mapping.put('C_Contract__c', convertNull(qcisCntr.Id));                                   // 電力契約

                // カスタムメタデータを基にマッピングする
                mapping = mpgCmnClass.mapContractToQuickCIS(ci, mapping, 'mappingAcctCiMst');

                returnMapping.put(fieldName, mapping);
            }
        }
        return returnMapping;
    }


    /**
     * QuickCIS設定料金アイテム（需要家別）マスタ（子）の作成用マッピングデータを生成
     * @param ci ARVE契約商品
     * @param qcisCntrParent QuickCIS※電力契約（親）
     * @param delMasterInfoMap QuickCIS※設定料金アイテム（需要家別）マスタID、ARVE契約商品IDマップ
     * @param masterInfoList 契約商品に紐づく※設定料金アイテム（需要家別）マスタIDリスト
     * @return Map<String, Map<String, String>> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    // 2026/02/12 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update Start
    //private Map<String, Map<String, String>> mappingAcctCiMstChild(
        //CMN_ContractItem__c ci, CMN_QuickCISRecord qcisCntrParent, Map<String, String> delMasterInfoMap, List<String> masterInfoList) {
    private Map<String, Map<String, String>> mappingAcctCiMstChild(
            CMN_ContractItem__c ci, Map<String, CMN_QuickCISRecord> qcisCntrMap, Map<String, String> delMasterInfoMap, List<String> masterInfoList) {
            // 紐づけ元契約商品.QuickCIS契約番号
            String qcisCntrParentId = ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c;
            // ※電力契約（親）           
            CMN_QuickCISRecord qcisCntrParent = qcisCntrMap.get(qcisCntrParentId);
           
    // 2026/02/12 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update End
        // マッピング格納用マップ  Map<作成パターン, Map<項目名, 値>>
        Map<String, Map<String, String>> returnMapping = new Map<String, Map<String, String>>();

        // 紐づけ元契約商品.商品ID
        String lsStockKeepingUnit = ci.CMN_LinkedSourceContractItem__r.CMN_StockKeepingUnit__c;
        // 商品ID
        String ciStockKeepingUnit = ci.CMN_StockKeepingUnit__c;
        if(Test.isRunningTest()) {
            lsStockKeepingUnit = lsStockKeepingUnit.removeEnd('UNIT');
            ciStockKeepingUnit = ciStockKeepingUnit.removeEnd('UNIT');
        }

        // 付帯メニュー・窓情報
        String additionalMenuOrWindowInfo;
        String blendingTargetPriceItemType;
        // キー1：紐づけ元契約商品.商品ID + 供給地点特定番号の上2桁 + 商品ID + 単価情報の上4桁
        String menuKey1 = lsStockKeepingUnit
                    + ci.CMN_SupplyPointSpecificNum__c?.left(2)
                    + ciStockKeepingUnit
                    + ci.CMN_UnitPriceKbn__c?.left(4);
        // キー2：商品ID
        String menuKey2 = ciStockKeepingUnit;
        // カスタムメタデータ型「付帯メニュー・窓情報」からキー1またはキー2で取得
        additionalMenuOrWindowInfo = CMN_QuickCISAddMenuOrWindowInfo_Setting__mdt.getInstance(menuKey1)?.CMN_AdditionalMenuOrWindowInfo__c;
        if(String.isBlank(additionalMenuOrWindowInfo)) {
            additionalMenuOrWindowInfo = CMN_QuickCISAddMenuOrWindowInfo_Setting__mdt.getInstance(menuKey2)?.CMN_AdditionalMenuOrWindowInfo__c;
            blendingTargetPriceItemType = CMN_QuickCISAddMenuOrWindowInfo_Setting__mdt.getInstance(menuKey2)?.CMN_BlendingTargetPriceItemType__c;
        }
        // キーから付帯メニュー・窓情報を特定できなかった場合は作成対象外
        if(String.isBlank(additionalMenuOrWindowInfo)) {
            return returnMapping;
        }
        
        // 契約開始日
        Date contractStartDate = ci.CMN_ContractStartDate__c;
        // 契約終了日
        Date contractEndDate = ci.CMN_ContractEndDate__c;
        // 適用開始日
        Date startApplyDate = ci.CMN_StartApplyDate__c;
        // 適用終了日
        Date endApplyDate = ci.CMN_EndApplyDate__c;

        // 設定料金アイテム（需要家別）情報取り出し
        Map<String, String> masterInfoMap = new Map<String, String>();
        for(String masterInfo : masterInfoList) {
            String masterInfoRec = masterInfo.substringAfter('：');
            if(!String.isBlank(masterInfoRec)) {
                if(masterInfo.contains('個別単価なし①')) {
                    masterInfoMap.put('notIndividual', masterInfoRec);
                } else if(masterInfo.contains('個別単価①')) {
                    masterInfoMap.put('individual', masterInfoRec);
                } else if(masterInfo.contains('通常単価1①')) {
                    masterInfoMap.put('normal1', masterInfoRec);
                } else if(masterInfo.contains('通常単価2①')) {
                    masterInfoMap.put('normal2', masterInfoRec);
                }
            }
        }
        // 作成パターンの判定
        List<String> createPttrnList = new List<String>();
        // 個別単価フラグがTRUE
        if(ci.CMN_IndividualUnitPriceFlg__c) {
            // 契約開始日 = 適用開始日
            if(contractStartDate == startApplyDate) {
                // 契約終了日 = 適用終了日（作成パターン：個別単価）
                if(contractEndDate == endApplyDate) {
                    createPttrnList.add('individual');
                    //作成パターン：個別単価以外のレコードを削除リストに格納
                    if(masterInfoMap.containsKey('normal1')) {
                        delMasterInfoMap.put(masterInfoMap.get('normal1'), ci.Id);
                    }
                    if(masterInfoMap.containsKey('normal2')) {
                        delMasterInfoMap.put(masterInfoMap.get('normal2'), ci.Id);
                    }
                    if(masterInfoMap.containsKey('notIndividual')) {
                        delMasterInfoMap.put(masterInfoMap.get('notIndividual'), ci.Id);
                    }
                // 契約終了日 > 適用終了日（作成パターン：個別単価、通常単価2）
                }else if(contractEndDate > endApplyDate) {
                    createPttrnList.add('individual');
                    createPttrnList.add('normal2');
                    //作成パターン：個別単価、通常単価2以外のレコードを削除リストに格納
                    if(masterInfoMap.containsKey('normal1')) {
                        delMasterInfoMap.put(masterInfoMap.get('normal1'), ci.Id);
                    }
                    if(masterInfoMap.containsKey('notIndividual')) {
                        delMasterInfoMap.put(masterInfoMap.get('notIndividual'), ci.Id);
                    }
                }
            // 契約開始日 < 適用開始日
            }else if(contractStartDate < startApplyDate) {
                // 契約終了日 = 適用終了日（作成パターン：個別単価、通常単価1）
                if(contractEndDate == endApplyDate) {
                    createPttrnList.add('individual');
                    createPttrnList.add('normal1');
                    //作成パターン：個別単価、通常単価1以外のレコードを削除リストに格納
                    if(masterInfoMap.containsKey('normal2')) {
                        delMasterInfoMap.put(masterInfoMap.get('normal2'), ci.Id);
                    }
                    if(masterInfoMap.containsKey('notIndividual')) {
                        delMasterInfoMap.put(masterInfoMap.get('notIndividual'), ci.Id);
                    }
                // 契約終了日 > 適用終了日（作成パターン：個別単価、通常単価1、通常単価2）
                }else if(contractEndDate > endApplyDate) {
                    createPttrnList.add('individual');
                    createPttrnList.add('normal1');
                    createPttrnList.add('normal2');
                    //作成パターン：個別単価、通常単価1、通常単価2以外のレコードを削除リストに格納
                    if(masterInfoMap.containsKey('notIndividual')) {
                        delMasterInfoMap.put(masterInfoMap.get('notIndividual'), ci.Id);
                    }
                }
            }
        // 個別単価フラグがFALSE（作成パターン：個別単価なし）
        }else {
            createPttrnList.add('notIndividual');
            //作成パターン：個別単価なし以外のレコードを削除リストに格納
            if(masterInfoMap.containsKey('normal1')) {
                delMasterInfoMap.put(masterInfoMap.get('normal1'), ci.Id);
            } 
            if(masterInfoMap.containsKey('normal2')) {
                delMasterInfoMap.put(masterInfoMap.get('normal2'), ci.Id);
            } 
            if(masterInfoMap.containsKey('individual')) 
                delMasterInfoMap.put(masterInfoMap.get('individual'), ci.Id);{
            }
        }

        // マッピング使用変数の生成
        for(String createPttrn : createPttrnList) {

            // 個別単価
            Decimal individualUnitPrice;
            // 設定値：契約商品.基本料金（対象：個別単価）
            if(new Set<String>{'individual'}.contains(createPttrn)) {
                individualUnitPrice = ci.CMN_BasicUnitPrice__c;
            }

            // 適用開始日
            Date applicableStartDate;
            // 設定値：契約商品.適用開始日（対象：個別単価）
            if(new Set<String>{'individual'}.contains(createPttrn)) {
                applicableStartDate = startApplyDate;
            // 設定値：契約商品.契約開始日（対象：個別単価なし、通常単価1）
            }else if(new Set<String>{'notIndividual', 'normal1'}.contains(createPttrn)) {
                applicableStartDate = contractStartDate;
            // 設定値：契約商品.適用終了日＋1日（対象：通常単価2）
            }else if(new Set<String>{'normal2'}.contains(createPttrn)) {
                applicableStartDate = endApplyDate.addDays(1);
            }

            // 適用終了日
            Date applicableEndDate;
            // 設定値：契約商品.適用終了日（対象：個別単価）
            if(new Set<String>{'individual'}.contains(createPttrn)) {
                applicableEndDate = endApplyDate;
            // 設定値：契約商品.適用開始日－1日（対象：通常単価1）
            }else if(new Set<String>{'normal1'}.contains(createPttrn)) {
                applicableEndDate = startApplyDate.addDays(-1);
            // 設定値：契約商品.契約終了日（対象：個別単価なし、通常単価2）
            }else if(new Set<String>{'notIndividual', 'normal2'}.contains(createPttrn)) {
                applicableEndDate = contractEndDate;
            }

            // マッピング
            Map<String, String> mapping = new Map<String, String>();
            if(masterInfoMap.containsKey(createPttrn)) {
                mapping.put('Id', convertNull(masterInfoMap.get(createPttrn)));                             // ID
            }
            mapping.put('C_AdditionalMenuOrWindowInformation__c', convertNull(additionalMenuOrWindowInfo)); // 付帯メニュー・窓情報
            mapping.put('C_BlendingTargetPriceItemType__c', convertNull(blendingTargetPriceItemType));      // ブレンド対象料金アイテム種別
            mapping.put('C_IndividualUnitPrice__c', convertNull(individualUnitPrice));                      // 個別単価
            mapping.put('C_ApplicableStartDate__c', '"' + String.valueOf(applicableStartDate) + '"');       // 適用開始日
            mapping.put('C_ApplicableEndDate__c', '"' + String.valueOf(applicableEndDate) + '"');           // 適用終了日
            // 2026/02/20 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update Start
            //mapping.put('C_Contract__c', '"' + qcisCntrParent.Id + '"');                                  // 電力契約
            if(qcisCntrParent != null){
                    mapping.put('C_Contract__c', '"' + qcisCntrParent.Id + '"');                            // 電力契約
            }            

            // マッピング（継続利用の複製廃止の場合）
            if(ci.CMN_LinkageKbn__c == LINKAGEKBN_D 
               && ci.CMN_LinkedSourceContractItem__r != null 
               && ci.CMN_ContinuedUseFlg__c
               && ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__c != null
            ){
                //紐づけ元契約商品.複製契約商品.QuickCIS契約番号（複製後）に対応する電力契約.継続利用契約データ移行状況が「移行完了」か 
                String reproducedQCISContractSts = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c)?.ContinuedUseMigrationStatus;         
                //主契約の後から連携した場合、「紐づけ元契約商品.複製契約商品.QuickCIS契約番号（複製後）」を設定
                if(reproducedQCISContractSts == 'Migrated'){
                    //設定料金アイテム（需要家別）マスタ.電力契約
                    mapping.put('C_Contract__c', '"' + qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c)?.id + '"');
                    //主契約と同時に連携した場合、「紐づけ元契約商品.複製契約商品.QuickCIS契約番号」を設定
                }else{
                    //設定料金アイテム（需要家別）マスタ.電力契約
                    mapping.put('C_Contract__c', '"' + qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproduceContractItem__r.CMN_QCISContractId__c)?.id + '"');
                }         

            // マッピング（それ以外の複製契約に紐づく付帯 または 複製契約に紐づかない付帯の場合）
            }else if(ci.CMN_LinkedSourceContractItem__c != null){
                         
                        //付帯契約の場合(契約商品.紐づけ元契約商品が空ではない)
                        //紐づけ元契約商品.QuickCIS契約番号（複製後）に対応する電力契約.継続利用契約データ移行状況が「移行完了」かどうか             
                        String reproducedQCISContractSts = qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproducedQCISContractId__c)?.ContinuedUseMigrationStatus;
                        //主契約の後から連携した場合、「紐づけ元契約商品（主契約）.QuickCIS契約番号」を設定
                        if(reproducedQCISContractSts == null || reproducedQCISContractSts == 'Migrated'){
                            //設定料金アイテム（需要家別）マスタ.電力契約
                            mapping.put('C_Contract__c', '"' + qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_QCISContractId__c)?.id + '"'); 
                            //主契約と同時に連携した場合、「紐づけ元契約商品（主契約）.QuickCIS契約番号（複製後）」を設定
                        }else{      
                            //設定料金アイテム（需要家別）マスタ.電力契約
                            mapping.put('C_Contract__c', '"' + qcisCntrMap.get(ci.CMN_LinkedSourceContractItem__r.CMN_ReproducedQCISContractId__c)?.id + '"');
                        }
                
            }           
            // 2026/02/20 「PRICE_REVISION_2025-1547 追加要件①」 熊 Update End
            // カスタムメタデータを基にマッピングする
            mapping = mpgCmnClass.mapContractToQuickCIS(ci, mapping, 'mappingAcctCiMstChild');

            returnMapping.put(createPttrn, mapping);
        }
        return returnMapping;
    }


    /**
     * QuickCIS※I／F連携情報の更新用マッピングデータを生成
     * @param ci ARVE契約商品
     * @return Map<String, String> マッピングデータ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private Map<String, String> mappingLnkgMng(CMN_ContractItem__c ci, Map<String, CMN_QuickCISRecord> qcisCntrMap) {

        // マッピング格納用マップ
        Map<String, String> mapping = new Map<String, String>();

        // マッピング
        mapping.put('Id', '"' + ci.CMN_LinkageManagementSfid__c + '"'); // ID
        mapping.put('dcis2__Contract__c', '"' + qcisCntrMap.get(ci.CMN_QCISContractId__c).Id + '"'); // 電力契約

        return mapping;
    }

    // 口座名義カナ1
    private String getBankAccNameKana(CMN_ContractItem__c ci){
        // 口座名義カナ1と口座名義カナ2に値がある場合
        if (!String.isBlank(ci.CMN_PaymentInfo__r.CMN_BankAccNameKana__c) && !String.isBlank(ci.CMN_PaymentInfo__r.CMN_BankAccNameKana2__c)) {

            // 口座名義カナ1,口座名義カナ2の値が21文字以上の場合は後続処理を実施しない
            if (ci.CMN_PaymentInfo__r.CMN_BankAccNameKana__c.length() >= 21 || ci.CMN_PaymentInfo__r.CMN_BankAccNameKana2__c.length() >= 21)  {
                return null;
            }
            // 口座名義カナ2を20文字になるようにパディング
            String bankAccNameKana2Padded = ci.CMN_PaymentInfo__r.CMN_BankAccNameKana2__c.rightPad(20);

            // 結合:口座名義カナ2（パディング後） + 口座名義カナ1
            String bankAccNameKana = bankAccNameKana2Padded + ci.CMN_PaymentInfo__r.CMN_BankAccNameKana__c;
                return bankAccNameKana;

        // 口座名義カナ1のみに値がある場合
        } else if (!String.isBlank(ci.CMN_PaymentInfo__r.CMN_BankAccNameKana__c) && String.isBlank(ci.CMN_PaymentInfo__r.CMN_BankAccNameKana2__c)) {
            // 口座名義カナ1を設定
            String bankAccNameKana = ci.CMN_PaymentInfo__r.CMN_BankAccNameKana__c;
            return bankAccNameKana;
        // 上記以外
        } else {
            return null;
        }
    }


    /**
     * 文字列の空白値変換
     * @param str 対象文字列
     * @return String 変換後文字列
     * @throws なし
     * @see なし
     */
    private String convertNull(String str) {
        return (String.isBlank(str) ? '""': '"' + str + '"');
    }


    /**
     * 日付を文字列に変換
     * @param dt 対象日付
     * @return String 変換後文字列
     * @throws なし
     * @see なし
     */
    private String convertNull(Date dt) {
        return (dt == null ? null : '"' + String.valueOf(dt) + '"');
    }


    /**
     * 数値（Integer）を文字列に変換
     * @param int 対象数値
     * @return String 変換後文字列
     * @throws なし
     * @see なし
     */
    private String convertNull(Integer i) {
        return (i == null ? null : '"' + String.valueOf(i) + '"');
    }

    /**
     * 数値（Decimal）を文字列に変換
     * @param dec 対象数値
     * @return String 変換後文字列
     * @throws なし
     * @see なし
     */
    private String convertNull(Decimal dec) {
        return (dec == null ? null : '"' + String.valueOf(dec) + '"');
    }

    /**
     * 分割元契約商品から最新の連番値を取得
     * @param ciIdSet 分割元契約商品IDセット
     * @return divSeqNumMap 分割元契約商品ID-連番値マップ
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private Map<Id, Decimal> getDivisionSeqNum(Set<Id> ciIdSet) {
        Map<Id, Decimal> divSeqNumMap = new Map<Id, Decimal>();
        
        for (CMN_ContractItem__c ci : [
            SELECT Id, CMN_DivisionSeqNum__c
            FROM CMN_ContractItem__c
            WHERE Id IN :ciIdSet
            FOR UPDATE
        ]) {
            divSeqNumMap.put(ci.Id, ci.CMN_DivisionSeqNum__c);
        }

        return divSeqNumMap;
    }

    /**
     * 分割元契約商品を最新の連番値で更新
     * @param divSeqNumMap 分割元契約商品ID-連番値マップ
     * @return なし
     * @throws なし
     * @see なし
     */
    @TestVisible 
    private void updateDivisionSeqNum(Map<Id, Decimal> divSeqNumMap) {
        List<CMN_ContractItem__c> updList = new List<CMN_ContractItem__c>();
        
        for (Id id : divSeqNumMap.keySet()) {
            CMN_ContractItem__c ci = new CMN_ContractItem__c(
                Id = id,
                CMN_DivisionSeqNum__c = divSeqNumMap.get(id)
            );
            updList.add(ci);
        }

        Database.update(updList, false);
    }

    /**
     * 支払情報（最新履歴）を取得
     * @param 契約商品マップ
     * @return key:連携対象契約商品(契約商品ID) value:支払情報履歴レコード
     * @throws なし
     * @see なし
     */
    @TestVisible
    private Map<Id,CMN_PaymentInfo__c> getPayInfoLastHistoryMap(Map<Id,CMN_ContractItem__c> tgtMap) {

        Set<Id> targetPaymentIds = new Set<Id>();
        Set<String> targetKbn = new Set<String>{'脱退→新規', '脱退→加入'};
        Map<Id, CMN_PaymentInfo__c> pilhMap = new Map<Id, CMN_PaymentInfo__c>();
        // WHERE句に使用する変数の用意
        for(CMN_ContractItem__c ci : tgtMap.values()){
            if (targetKbn.contains(ci.CMN_SummaryInvoiceMasterUpdateKbn__c)) {
                targetPaymentIds.add(ci.Id);
            }
        }

        // 処理対象がなければ、処理を中断
        if(targetPaymentIds.isEmpty()){
            return pilhMap;
        }
        
        // 支払情報（最新履歴）を取得するクエリを生成
        String query = 
        'SELECT Id, CMN_LinkTargetContractItem__c, CMN_InvoiceMethod__c ' +
        'FROM CMN_PaymentInfo__c ' +
        'WHERE CMN_LinkTargetContractItem__c IN :targetPaymentIds ';

        // 契約連携バッチの開始時刻より前（＝直前の契約連携バッチで作られた履歴を除外）の条件を追加
        if(contractBatchStartTime != null){
            query += 'AND CMN_HistoryCreateDatetime__c < :contractBatchStartTime ';
        }
        query += 'ORDER BY CMN_LinkTargetContractItem__c, CMN_HistoryCreateDatetime__c DESC NULLS LAST';

        for (CMN_PaymentInfo__c pih : Database.query(query)){
            if(!pilhMap.containsKey(pih.CMN_LinkTargetContractItem__c)){
                //同一連携対象契約商品の中で異動履歴作成日時が一番新しいものを最新履歴レコードとする
                pilhMap.put(pih.CMN_LinkTargetContractItem__c, pih);
            }
        }
        return pilhMap;
    }

    /**
     * 最新の契約連携バッチ開始時刻を取得
     * @param なし
     * @return  なし
     * @throws なし
     * @see なし
     */
    private void getContractBatchStartTime() {
        List<AsyncApexJob> apexJob = [SELECT CreatedDate
                                      FROM AsyncApexJob 
                                      WHERE ApexClass.Name = 'CMN_AutoChangeContractBatch' 
                                      AND JobType = 'BatchApex'
                                      AND Status = 'Completed'
                                      ORDER BY CreatedDate DESC LIMIT 1
                                     ];
        if(!apexJob.isEmpty()){
            contractBatchStartTime = apexJob[0].CreatedDate;
        }
    }

    // ----------------------------------------
    // 内部クラス
    // ----------------------------------------

    /**
     * QuickCISレコード取得レスポンス(JSON)格納用クラス
     */
    public class QCIS_RecordRes {

        // 取得レコード
        public CMN_QuickCISRecord[] records{get; set;}

        /**
         * コンストラクタ
         * @param なし
         * @return なし
         * @throws なし
         * @see なし
         */
        public QCIS_RecordRes() {
            records = new CMN_QuickCISRecord[]{};
        }
    }


    /**
     * QuickCIS更新レスポンス(JSON)格納用クラス
     */
    public class QCIS_APIRes {
        
        public String id{get; set;}               // ID
        public Boolean success{get; set;}         // 成否
        public List<QCIS_Error> errors{get; set;} // エラー
        public Boolean created{get; set;}         // 作成成否

        /**
         * コンストラクタ
         * @param なし
         * @return なし
         * @throws なし
         * @see なし
         */
        public QCIS_APIRes() {
            errors = new List<QCIS_Error>();
        }
    }


    /**
     * QuickCIS更新レスポンス(JSON)内のエラー格納用クラス
     */
    public class QCIS_Error {
        
        public String statusCode{get; set;} // ステータスコード
        public String message{get; set;}    // メッセージ
        public String[] fields{get; set;}   // 項目名

        /**
         * コンストラクタ
         * @param なし
         * @return なし
         * @throws なし
         * @see なし
         */
        public QCIS_Error() {
            fields = new String[]{};
        }
    }
}