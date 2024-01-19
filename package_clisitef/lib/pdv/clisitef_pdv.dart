library clisitef;

import 'package:flutter_clisitef/clisitef_sdk.dart';
import 'package:flutter_clisitef/model/clisitef_configuration.dart';
import 'package:flutter_clisitef/model/clisitef_data.dart';
import 'package:flutter_clisitef/model/clisitef_resp.dart';

import 'package:flutter_clisitef/model/pinpad_events.dart';
import 'package:flutter_clisitef/model/pinpad_information.dart';
import 'package:flutter_clisitef/model/transaction.dart';
import 'package:flutter_clisitef/model/transaction_events.dart';
import 'package:flutter_clisitef/pdv/stream/data_stream.dart';
import 'package:flutter_clisitef/pdv/stream/pin_pad_stream.dart';
import 'package:flutter_clisitef/pdv/stream/transaction_stream.dart';
import 'package:flutter/services.dart';

class CliSiTefPDV {
  CliSiTefPDV(
      {required this.client,
      required this.configuration,
      this.isSimulated = false}) {
    cliSiTefResp = CliSiTefResp();
    _isReady = _init();
    client.setEventHandler(null, onPinPadEvent);
    client.setDataHandler(onData);
  }

  Future _init() async {
    _isReady = client.configure(
      configuration.enderecoSitef,
      configuration.codigoLoja,
      configuration.numeroTerminal,
      configuration.cnpjAutomacao,
      configuration.cnpjLoja,
      configuration.tipoPinPad,
      parametrosAdicionais: configuration.parametrosAdicionais,
    );
  }

  late Future _isReady;

  late CliSiTefResp cliSiTefResp;

  Map<int, String> cliSitetRespMap = {};

  Future get isReady => _isReady;

  CliSiTefConfiguration configuration;

  CliSiTefSDK client;

  TransactionStream? _transactionStream;

  bool isSimulated;

  final PinPadStream _pinPadStream = PinPadStream();

  PinPadStream get pinPadStream => _pinPadStream;

  final DataStream _dataStream = DataStream();

  DataStream get dataStream => _dataStream;

  Future<Stream<Transaction>> payment(
    int modalidade,
    double valor, {
    required String cupomFiscal,
    required DateTime dataFiscal,
    String operador = '',
    String restricoes = '',
  }) async {
    if (_transactionStream != null) {
      throw Exception('Another transaction is already in progress.');
    }
    cliSiTefResp.clear();
    cliSitetRespMap = {};
    try {
      bool success = await client.startTransaction(
        modalidade,
        valor,
        cupomFiscal,
        dataFiscal,
        operador,
        restricoes: restricoes,
      );
      if (!success) {
        throw Exception('Unable to start payment process');
      }
    } on Exception {
      rethrow;
    }

    _transactionStream = TransactionStream(
      onCancel: () => client.abortTransaction(),
    );
    client.setEventHandler(onTransactionEvent, onPinPadEvent);
    return _transactionStream!.stream;
  }

  Future<bool> continueTransaction(String data) async {
    return client.continueTransaction(data);
  }

  Future<bool> isPinPadPresent() async {
    if (isSimulated) {
      PinPadInformation pinPadSimulatedInfo =
          PinPadInformation(isPresent: true);
      pinPadSimulatedInfo.isConnected = true;
      pinPadSimulatedInfo.isReady = true;
      pinPadStream.emit(pinPadSimulatedInfo);
      return true;
    }
    PinPadInformation pinPad = await client.getPinpadInformation();
    PinPadInformation pinPadStreamInfo = _pinPadStream.pinPadInfo;
    pinPadStreamInfo.isPresent = pinPad.isPresent;
    pinPadStream.emit(pinPadStreamInfo);
    return _pinPadStream.pinPadInfo.isPresent;
  }

  Future<void> cancelTransaction() async {
    try {
      await client.finishLastTransaction(false);
    } on PlatformException catch (e) {
      if (e.code == '-12') {
        await client.abortTransaction();
      } else {
        rethrow;
      }
    }

    if (_transactionStream != null) {
      _transactionStream!.success(false);
      _transactionStream!.emit(_transactionStream!.transaction);
    }
  }

  onTransactionEvent(TransactionEvents event, {PlatformException? exception}) {
    Transaction? t = _transactionStream?.transaction;
    if (t != null) {
      switch (event) {
        case TransactionEvents.transactionConfirm:
          _transactionStream?.success(true);
          break;
        case TransactionEvents.transactionOk:
          _transactionStream?.success(true);
          break;
        case TransactionEvents.transactionError:
        case TransactionEvents.transactionFailed:
          _transactionStream?.success(false);
          break;
        default:
        //noop
      }
      _transactionStream?.event(event);
      _transactionStream?.done();
      _transactionStream = null;
    }
  }

  onPinPadEvent(PinPadEvents event, {PlatformException? exception}) {
    PinPadInformation pinPad = _pinPadStream.pinPadInfo;
    pinPad.event = event;
    switch (event) {
      case PinPadEvents.startBluetooth:
        pinPad.waiting = true;
        pinPad.isBluetoothEnabled = false;
        break;
      case PinPadEvents.endBluetooth:
        pinPad.waiting = false;
        pinPad.isBluetoothEnabled = true;
        break;
      case PinPadEvents.waitingPinPadConnection:
        pinPad.waiting = true;
        pinPad.isConnected = false;
        break;
      case PinPadEvents.pinPadOk:
        pinPad.waiting = false;
        pinPad.isConnected = true;
        break;
      case PinPadEvents.waitingPinPadBluetooth:
        pinPad.waiting = true;
        pinPad.isReady = false;
        break;
      case PinPadEvents.pinPadBluetoothConnected:
        pinPad.waiting = false;
        pinPad.isReady = true;
        break;
      case PinPadEvents.pinPadBluetoothDisconnected:
        pinPad.waiting = false;
        pinPad.isReady = false;
        break;
      case PinPadEvents.unknown:
      case PinPadEvents.genericError:
        _pinPadStream.error(exception ?? 'Unhandled event $event');
        return;
    }
    _pinPadStream.emit(pinPad);
  }

  void onData(CliSiTefData data) {
    if ((data.fieldId > 0) && (data.buffer.isNotEmpty)) {
      cliSitetRespMap[data.fieldId] = data.buffer;
    }

    switch (data.fieldId) {
      case 29:
        cliSiTefResp.digitado = true;
        break;
      case 100:
        cliSiTefResp.modalidadePagamento = data.buffer;
        break;
      case 101:
        cliSiTefResp.modalidadePagtoExtenso = data.buffer;
        break;
      case 102:
        cliSiTefResp.modalidadePagtoDescrita = data.buffer;
        break;
      case 105:
        cliSiTefResp.dataHoraTransacao = data.buffer;
        break;
      case 106:
        cliSiTefResp.idCarteiraDigital = data.buffer;
        break;
      case 107:
        cliSiTefResp.nomeCarteiraDigital = data.buffer;
        break;
      case 110:
        cliSiTefResp.modalidadeCancelamento = data.buffer;
        break;
      case 111:
        cliSiTefResp.modalidadeCancelamentoExtenso = data.buffer;
        break;
      case 112:
        cliSiTefResp.modalidadeCancelamentoDescrita = data.buffer;
        break;
      case 120:
        cliSiTefResp.autenticacao = data.buffer;
        break;
      case 121:
        cliSiTefResp.viaCliente = data.buffer;
        break;
      case 122:
        cliSiTefResp.viaEstabelecimento = data.buffer;
        break;
      case 123:
        cliSiTefResp.tipoComprovante = data.buffer;
        break;
      case 125:
        cliSiTefResp.codigoVoucher = data.buffer;
        break;
      case 130:
        cliSiTefResp.saque = double.parse(data.buffer);
        break;
      case 131:
        cliSiTefResp.instituicao = data.buffer;
        break;
      case 132:
        cliSiTefResp.codigoBandeiraPadrao = data.buffer;
        break;
      case 133:
        cliSiTefResp.nsuTef = data.buffer;
        break;
      case 134:
        cliSiTefResp.nsuHost = data.buffer;
        break;
      case 135:
        cliSiTefResp.codigoAutorizacao = data.buffer;
        break;
      case 136:
        cliSiTefResp.bin = data.buffer;
        break;
      case 137:
        cliSiTefResp.saldoAPagar = double.parse(data.buffer);
        break;
      case 138:
        cliSiTefResp.valorTotalRecebido = double.parse(data.buffer);
        break;
      case 139:
        cliSiTefResp.valorEntrada = double.parse(data.buffer);
        break;
      case 140:
        cliSiTefResp.dataPrimeiraParcela = data.buffer;
        break;
      case 143:
        cliSiTefResp.valorGorjeta = double.parse(data.buffer);
        break;
      case 144:
        cliSiTefResp.valorDevolucao = double.parse(data.buffer);
        break;
      case 145:
        cliSiTefResp.valorPagamento = double.parse(data.buffer);
        break;
      case 146:
        cliSiTefResp.valorASerCancelado = double.parse(data.buffer);
        break;
      case 155:
        cliSiTefResp.tipoCartaoBonus = data.buffer;
        break;
      case 156:
        cliSiTefResp.nomeInstituicao = data.buffer;
        break;
      case 157:
        cliSiTefResp.codigoEstabelecimento = data.buffer;
        break;
      case 158:
        cliSiTefResp.codigoRedeAutorizadora = data.buffer;
        break;
      case 160:
        cliSiTefResp.numeroCupomOriginal = data.buffer;
        break;
      case 161:
        cliSiTefResp.numeroIdentificadorCupomPagamento = data.buffer;
        break;
      case 200:
        cliSiTefResp.saldoDisponivel = double.parse(data.buffer);
        break;
      case 201:
        cliSiTefResp.saldoBloqueado = double.parse(data.buffer);
        break;
      case 501:
        cliSiTefResp.tipoDocumentoConsultado = data.buffer;
        break;
      case 502:
        cliSiTefResp.numeroDocumento = data.buffer;
        break;
      case 504:
        cliSiTefResp.taxaServico = double.tryParse(data.buffer) ?? 0;
        break;
      case 505:
        cliSiTefResp.numeroParcelas = int.tryParse(data.buffer) ?? 0;
        break;
      case 506:
        cliSiTefResp.dataPreDatado = data.buffer;
        break;
      case 507:
        cliSiTefResp.primeiraParcela = data.buffer;
        break;
      case 508:
        cliSiTefResp.diasEntreParcelas = int.tryParse(data.buffer) ?? 0;
        break;
      case 509:
        cliSiTefResp.mesFechado = data.buffer;
        break;
      case 510:
        cliSiTefResp.garantia = data.buffer;
        break;
      case 511:
        cliSiTefResp.numeroParcelasCDC = int.tryParse(data.buffer) ?? 0;
        break;
      case 512:
        cliSiTefResp.numeroCartaoCreditoDigitado = data.buffer;
        break;
      case 513:
        cliSiTefResp.dataVencimentoCartao = data.buffer;
        break;
      case 514:
        cliSiTefResp.codigoSegurancaCartao = data.buffer;
        break;
      case 515:
        cliSiTefResp.dataTransacaoCanceladaReimpressa = data.buffer;
        break;
      case 516:
        cliSiTefResp.numeroDocumentoCanceladoReimpresso = data.buffer;
        break;
      case 670:
        cliSiTefResp.dadoPinPad = data.buffer;
        break;
      case 950:
        cliSiTefResp.cnpjCredenciadoraNFCE = data.buffer;
        break;
      case 951:
        cliSiTefResp.bandeiraNFCE = data.buffer;
        break;
      case 952:
        cliSiTefResp.numeroAutorizacaoNFCE = data.buffer;
        break;
      case 953:
        cliSiTefResp.codigoCredenciadoraSAT = data.buffer;
        break;
      case 1002:
        cliSiTefResp.dataValidadeCartao = data.buffer;
        break;
      case 1003:
        cliSiTefResp.nomePortadorCartao = data.buffer;
        break;
      case 1190:
        cliSiTefResp.ultimosQuatroDigitosCartao = data.buffer;
        break;
      case 1321:
        cliSiTefResp.nsuHostAutorizadorTransacaoCancelada = data.buffer;
        break;
      case 4153:
        cliSiTefResp.codigoPSP = data.buffer;
        break;
    }
    _dataStream.sink.add(data);
  }
}
