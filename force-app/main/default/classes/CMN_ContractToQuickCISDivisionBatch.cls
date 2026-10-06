/**
 * 契約基盤QuickCIS連携（分割先）バッチ
 * 契約基盤上で契約化が完了した分割元契約データを取得し、
 * QuickCISの以下オブジェクトのレコードを作成・更新する
 * ・※電力契約
 */
public without sharing class CMN_ContractToQuickCISDivisionBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    // APIリクエストクラス
    CMN_RestAPIRequest APIRequest = new CMN_RestAPIRequest('QuickCIS');
    // 契約基盤QuickCIS連携共通クラス
    CMN_ContractToQuickCISCommon common = new CMN_ContractToQuickCISCommon('Division');
    
    // エラーリスト
    List<EpccErrorList__c> errorList = new List<EpccErrorList__c>();

    // アクセストークン
    private String accessToken;
    // QuickCISレコードタイプマップ  Map<オブジェクト名, Map<レコードタイプAPI名, レコードタイプID>>
    private Map<String, Map<String, String>> qcisRecordTypeMap;
    // QuickCIS※料金メニューマップ Map<料金メニュー名, ※料金メニューID>
    private Map<String, String> qcisChargeMenuMap;

    //OCP_SFDC_DEV-80　リトライ回数
    private Integer retryCount = 0;
    //OCP_SFDC_DEV-80　リトライフラグ
    private Boolean retryFlg = false;
 
    
    // テストクラス用：レスポンスパターン
    @TestVisible String resPattern;

    /**
     * コンストラクタ
     * @param なし
     * @throws なし
     * @see なし
     */
    public CMN_ContractToQuickCISDivisionBatch() {
        // 処理なし
    }

    // OCP_SFDC_DEV-80対応　Start
    /**
     * コンストラクタ
     * @param intRetry:リトライ回数
     * @throws なし
     * @see なし
     */
    public CMN_ContractToQuickCISVsCstmNmBatch(Integer intRetry) {
        retryCount = intRetry;
    }
    // OCP_SFDC_DEV-80対応　End


    /**     * start
     * 処理対象のレコード取得
     * @param bc BatchableContext
     * @return Database.QueryLocator 処理対象レコード
     * @throws なし
     * @see CMN_RestAPIRequest
     * @see CMN_ContractToQuickCISCommon
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {

        // ----------------------------------------
        // QuickCIS初期処理
        // ----------------------------------------

        // Apexテスト実行時、共通クラスにリクエストパターンを設定
        if(Test.isRunningTest()) {
            common.resPattern = this.resPattern;
        }

        // QuickCIS初期接続処理（アクセストークン取得）
        this.accessToken = APIRequest.getAccessToken();
        // QuickCISからレコードタイプを取得
        this.qcisRecordTypeMap = common.getQcisRecordType(accessToken);
        // QuickCISから※料金メニューを取得
        this.qcisChargeMenuMap = common.getQcisChargeMenu(accessToken);
        
        // 処理に失敗した場合、エラーリストを作成
        String errMsg;
        if(String.isBlank(this.accessToken)) {
            // アクセストークン取得に失敗した場合
            errorList.add(common.createErrorList(common.ERRMSG001, null));
        }else if(this.qcisRecordTypeMap.isEmpty() || this.qcisChargeMenuMap.isEmpty()) {
            // QuickCISからのデータ取得に失敗した場合
            errorList.add(common.createErrorList(common.ERRMSG002, null));
        }
        
        // ----------------------------------------
        // ARVE対象レコードを取得
        // ----------------------------------------

        // ARVE契約商品を取得
        String query = common.setContractItemQuery();
        // QuickCIS初期処理に失敗していた場合、取得レコードを0件にしてfinishメソッドに進む
        if(!this.errorList.isEmpty()) {
            query += ' LIMIT 0'; 
        }

        return Database.getQueryLocator(query);
    }


    /**
     * execute
     * 契約商品 -> QuickCIS連携の実行
     * @param bc BatchableContext
     * @param scope 処理対象レコード 
     * @return なし
     * @throws なし
     * @see なし
     */
    public void execute(Database.BatchableContext bc, List<CMN_ContractItem__c> scope) {

        // 更新用契約商品リスト
        List<CMN_ContractItem__c> updList = new List<CMN_ContractItem__c>();
        // 処理対象契約商品マップ
        Map<Id, CMN_ContractItem__c> tgtMap = new Map<Id, CMN_ContractItem__c>();

        // ----------------------------------------
        // QuickCISデータを取得
        // 取引先 / ※電力契約 / ※I／F連携情報
        // ----------------------------------------

        // CISお客様番号セット
        Set<String> qcisCstNoSet = new Set<String>();
        // 契約番号セット
        Set<String> qcisCntrIdSet = new Set<String>();

        // 契約商品から必要情報をセットに追加
        for(CMN_ContractItem__c ci : scope) {
            qcisCstNoSet.add(ci.CMN_DivisionSource__r.CMN_VisualizationCustomerNum__c); // 分割元契約商品.見える化まとめコード
            qcisCntrIdSet.add(ci.CMN_QCISContractId__c); // QuickCIS契約番号
            qcisCntrIdSet.add(ci.CMN_DeleteContractItem__r.CMN_QCISContractId__c); // 複製廃止契約商品.QuickCIS契約番号
            qcisCntrIdSet.add(ci.CMN_DivisionSource__r.CMN_QCISContractId__c); // 分割元契約商品.QuickCIS契約番号
            // 2026/02/19 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add Start
            qcisCntrIdSet.add(ci.CMN_DivisionSource__r.CMN_ReproducedQCISContractId__c); // 分割元契約商品.QuickCIS契約番号（複製後）
            qcisCntrIdSet.add(ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_QCISContractId__c); // 分割元契約商品.複製契約商品.QuickCIS契約番号
            qcisCntrIdSet.add(ci.CMN_DivisionSource__r.CMN_ReproduceContractItem__r.CMN_ReproducedQCISContractId__c); // 分割元契約商品.複製契約商品.QuickCIS契約番号（複製後）
            // 2026/02/19 「PRICE_REVISION_2025-1547 追加要件①」 熊 Add End
        }
        // 各セットからnullを除外
        qcisCstNoSet.remove(null);
        qcisCntrIdSet.remove(null);

        // QuickCIS取引先  Map<取引先.※CISお客様番号, 取引先>
        Map<String, CMN_QuickCISRecord> qcisAccMap = common.getQcisAccount(this.accessToken, qcisCstNoSet, common.CONTRACT_QUICKCISBATCH);
        // QuickCIS※電力契約  Map<※電力契約.契約番号, ※電力契約>
        Map<String, CMN_QuickCISRecord> qcisCntrMap = common.getQcisContract(this.accessToken, this.qcisRecordTypeMap, qcisCntrIdSet, 'Name');
        
        // 取得時にエラーが発生しnullが返却された場合、エラーリストを作成して処理を終了
        if(qcisCntrMap == null || qcisAccMap == null) {
            errorList.add(common.createErrorList(common.ERRMSG002, new Map<Id, CMN_ContractItem__c>(scope).keySet()));
            return;
        }

        // ----------------------------------------
        // QuickCISデータ存在チェック
        // ----------------------------------------
        Set<Id> setId = new Set<Id>(); // 処理対象契約商品IDセット
        for(CMN_ContractItem__c ci : scope) {
            // 分割元※電力契約が存在しない場合処理対象外
            if (!common.isSourceLinked(ci, qcisCntrMap)) {
                continue;
            }
            setId.add(ci.id);
            // ARVE契約商品とQuickCIS※電力契約の整合性チェック
            common.checkContractItem(ci, qcisCntrMap);
            // 連携エラーの場合は更新対象に追加、それ以外は後続処理対象に追加
            if(ci.CMN_LinkSts__c == common.LINKSTS_ERR) {
                updList.add(ci);
            }else {
                tgtMap.put(ci.Id, ci);
            }
        }

        // ----------------------------------------
        // QuickCIS※電力契約の作成・更新
        // ----------------------------------------

        // APIリクエスト
        // QuickCIS※電力契約の作成・更新処理
        // ※処理内で作成した※電力契約はqcisCntrMapに追加される
        String errMsg = common.upsertQcisContractDivision(tgtMap, this.accessToken, this.qcisRecordTypeMap, qcisCntrMap, qcisAccMap, this.qcisChargeMenuMap);
        // エラーが発生した場合、エラーリストを作成して処理を終了
        if(!String.isBlank(errMsg)) {
            errorList.add(common.createErrorList(errMsg, setId));
            return;
        }
        // 連携エラーとなったARVE契約商品を処理対象マップから除外する
        for(CMN_ContractItem__c ci : new List<CMN_ContractItem__c>(tgtMap.values())) {            
            if(ci.CMN_LinkSts__c == common.LINKSTS_ERR) {

                //OCP_SFDC_DEV-80 start              
                // リトライ回数がCMN_MaxRetryCount回以下なら、リトライフラグをtrueにして処理対象マップから除外する
                if(retrycount < Integer.valueOf(System.Label.CMN_MaxRetryCount) || Test.isRunningTest()){
                    this.retryFlg = true;
                    tgtMap.remove(ci.Id);}
                    // リトライ回数がCMN_MaxRetryCount回を超えた場合、エラーリストに追加して処理対象マップから除外する
                    else{
                //OCP_SFDC_DEV-80 end  
                        pdList.add(ci);
                        tgtMap.remove(ci.Id);
                }   
                      
            }
}
       

        // ----------------------------------------
        // QuickCIS設定料金アイテム（需要家別）マスタの作成
        // ----------------------------------------

        // APIリクエスト
        // QuickCIS設定料金アイテム（需要家別）マスタの作成処理
        errMsg = common.insertAccountChargeItemMaster(tgtMap, this.accessToken, qcisCntrMap, this.qcisChargeMenuMap);
        // エラーが発生した場合、エラーリストを作成して処理を終了
        if(!String.isBlank(errMsg)) {
            errorList.add(common.createErrorList(errMsg, new Map<Id, CMN_ContractItem__c>(scope).keySet()));
            return;
        }
        // 連携エラーとなったARVE契約商品を処理対象マップから除外する koko
        for(CMN_ContractItem__c ci : new List<CMN_ContractItem__c>(tgtMap.values())) {            
            if(ci.CMN_LinkSts__c == common.LINKSTS_ERR) {
                updList.add(ci);
                tgtMap.remove(ci.Id);
            }
        }

        // ----------------------------------------
        // ARVE契約商品の更新
        // ----------------------------------------

        // 連携完了した契約商品の連携ステータスを更新
        updList.addAll(common.changeLinkStsLinked(tgtMap.values()));
        // 契約商品を更新
        List<Database.SaveResult> results = Database.update(updList, false);
        // エラーレコードがある場合、エラーリストを作成する
        Set<Id> errIdSet = new Set<Id>();
        for(Database.SaveResult result : results) {
            if(!result.isSuccess()) {
                errIdSet.add(result.getId());
            }
        }
        if(!errIdSet.isEmpty()) {
            errorList.add(common.createErrorList(common.ERRMSG003, errIdSet));
        }
    }


    /**
     * finish
     * エラーリストの登録
     * @param bc BatchableContext
     * @return なし
     * @throws なし
     * @see なし
     */
    public void finish(Database.BatchableContext bc) {

        // エラーリストを登録
        if(!this.errorList.isEmpty() ) {

        //OCP_SFDC_DEV-80対応 Start
             if(retryFlg){
                CMN_ContractToQuickCISVsCstmNmBatch b = new CMN_ContractToQuickCISVsCstmNmBatch(retryCount + 1);
            }else{
                CMN_ContractToQuickCISChildBatch b = new CMN_ContractToQuickCISChildBatch();
            }
            Database.executeBatch(b, 1);
        }else {
        // OCP_SFDC_DEV-80対応　End
            Database.insert(this.errorList, false);
        }
    }   
}