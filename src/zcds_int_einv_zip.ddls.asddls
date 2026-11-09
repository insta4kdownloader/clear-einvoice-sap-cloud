@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Extract Archive'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
/* =====================================================================
   The extract archive kept for the DATA_ZIP diagnostic, exposed so it can
   be downloaded. ZCL_EINV_ZIP_STORE writes the table; this makes the bytes
   reachable.

   READ ONLY. The behaviour declares no create, update or delete: the
   archive is written by the save phase of the submit action and is
   evidence of what was sent, so nothing should be able to edit it through
   the service. That also keeps this a plain read stream, which needs
   nothing in the behaviour definition beyond the mapping - a writable
   stream would.

   sizeCategory #L and no @UI.lineItem on CONTENT: the point of the stream
   is that the bytes are fetched by their own request when the link is
   pressed, not carried in every list response.
   ===================================================================== */
define view entity ZCDS_INT_EINV_ZIP as select from zteinv_zip
  association to parent ZCDS_INT_EINV_DOC as _Document
    on  $projection.BillingDocument    = _Document.BillingDocument
    and $projection.AccountingDocument = _Document.AccountingDocument
    and $projection.CompanyCode        = _Document.CompanyCode
    and $projection.FiscalYear         = _Document.FiscalYear
{
  key vbeln      as BillingDocument,
  key belnr      as AccountingDocument,
  key bukrs      as CompanyCode,
  key gjahr      as FiscalYear,

      command_id as CommandId,

      @Semantics.mimeType: true
      mimetype   as MimeType,

      filename   as FileName,

      /* The stream itself. MimeType and FileName are named here rather
         than hard-coded so the same entity would serve a future archive
         in another format without a view change; contentDisposition
         #ATTACHMENT is what makes the browser offer a Save dialog rather
         than trying to render a zip. */
      @Semantics.largeObject: { mimeType: 'MimeType',
                                fileName: 'FileName',
                                acceptableMimeTypes: [ 'application/zip' ],
                                contentDispositionPreference: #ATTACHMENT }
      content    as Content,

      crdat      as CreatedOn,
      crtime     as CreatedAt,

      _Document
}
