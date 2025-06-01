import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Credit Scoring PoC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CreditScoreScreen(),
    );
  }
}

class CreditScoreScreen extends StatefulWidget {
  const CreditScoreScreen({super.key});

  @override
  State<CreditScoreScreen> createState() => _CreditScoreScreenState();
}

class _CreditScoreScreenState extends State<CreditScoreScreen> {
  // --- Configuration ---
  final String _rpcUrl = dotenv.env['SEPOLIA_RPC_URL']!;
  final String _privateKey = dotenv.env['WALLET_PRIVATE_KEY']!;
  final String _contractAddress = "0x04Dd1eBa17E0d633feB0767439EF4cF1A722fc57";

  late Web3Client _web3client;
  late Credentials _credentials;
  late DeployedContract _contract;
  late ContractFunction _addOrUpdateBorrowerFunction;
  late ContractFunction _getBorrowerDetailsFunction;

  // --- UI State ---
  final _formKey = GlobalKey<FormState>();
  String _nid = '';
  String _name = '';
  int _accountBalanceScore = 85;
  int _paymentHistoryScore = 90;
  int _totalTransactionsScore = 70;
  int _totalRemainingLoanScore = 95;
  int _creditAgeScore = 80;
  int _professionalRiskFactorScore = 75;

  String _statusMessage = 'Please connect to the blockchain.';
  String _borrowerDetails = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initWeb3();
  }

  Future<void> _initWeb3() async {
    _web3client = Web3Client(_rpcUrl, Client());
    _credentials = EthPrivateKey.fromHex(_privateKey);

    try {
      String abiJson = await rootBundle.loadString('assets/CreditScoreABI.json');
      _contract = DeployedContract(
        ContractAbi.fromJson(abiJson, 'CreditScore'),
        EthereumAddress.fromHex(_contractAddress),
      );

      _addOrUpdateBorrowerFunction = _contract.function('addOrUpdateBorrower');
      _getBorrowerDetailsFunction = _contract.function('getBorrowerDetails');

      setState(() {
        _statusMessage = 'Ready to interact with the CreditScore contract.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: ${e.toString()}';
      });
    }
  }

  Future<void> _addOrUpdateBorrower() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Submitting data to the blockchain...';
      _borrowerDetails = '';
    });

    try {
      final txHash = await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _addOrUpdateBorrowerFunction,
          parameters: [
            _nid,
            _name,
            BigInt.from(_accountBalanceScore),
            BigInt.from(_paymentHistoryScore),
            BigInt.from(_totalTransactionsScore),
            BigInt.from(_totalRemainingLoanScore),
            BigInt.from(_creditAgeScore),
            BigInt.from(_professionalRiskFactorScore),
          ],
        ),
        chainId: 11155111, // Sepolia testnet chain ID
      );
      setState(() {
        _statusMessage = 'Transaction sent! Hash: $txHash. Please wait a moment, then fetch details.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBorrowerDetails() async {
    if (_nid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter NID to fetch details.')));
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching details for NID: $_nid...';
      _borrowerDetails = '';
    });

    try {
      final result = await _web3client.call(
        contract: _contract,
        function: _getBorrowerDetailsFunction,
        params: [_nid],
      );
      final borrowerData = result[0];
      setState(() {
        _borrowerDetails =
            "NID: ${borrowerData[0]}\n"
            "Name: ${borrowerData[1]}\n"
            "Account Balance Score: ${borrowerData[2]}\n"
            "Payment History Score: ${borrowerData[3]}\n"
            "Total Transactions Score: ${borrowerData[4]}\n"
            "Total Remaining Loan Score: ${borrowerData[5]}\n"
            "Credit Age Score: ${borrowerData[6]}\n"
            "Professional Risk Score: ${borrowerData[7]}\n"
            "FINAL CREDIT SCORE: ${borrowerData[8]}";
        _statusMessage = 'Details fetched successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching details. The borrower may not exist yet.';
        _borrowerDetails = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blockchain Credit Scoring')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Borrower NID'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                onSaved: (v) => _nid = v!,
                onChanged: (v) => _nid = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Borrower Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 20),
              // We will use sliders for scores for better UI
              _buildScoreSlider('Account Balance', _accountBalanceScore, (val) => setState(() => _accountBalanceScore = val)),
              _buildScoreSlider('Payment History', _paymentHistoryScore, (val) => setState(() => _paymentHistoryScore = val)),
              _buildScoreSlider('Total Transactions', _totalTransactionsScore, (val) => setState(() => _totalTransactionsScore = val)),
              _buildScoreSlider('Remaining Loan', _totalRemainingLoanScore, (val) => setState(() => _totalRemainingLoanScore = val)),
              _buildScoreSlider('Credit Age', _creditAgeScore, (val) => setState(() => _creditAgeScore = val)),
              _buildScoreSlider('Professional Risk', _professionalRiskFactorScore, (val) => setState(() => _professionalRiskFactorScore = val)),

              const SizedBox(height: 20),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              if (!_isLoading) ...[
                ElevatedButton(
                  onPressed: _addOrUpdateBorrower,
                  child: const Text('Add / Update Borrower'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _fetchBorrowerDetails,
                  child: const Text('Fetch Borrower Details'),
                ),
              ],
              const SizedBox(height: 20),
              Text('Status: $_statusMessage', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              if (_borrowerDetails.isNotEmpty)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(_borrowerDetails, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSlider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label Score: $value'),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: value.toString(),
          onChanged: (double newValue) {
            onChanged(newValue.round());
          },
        ),
      ],
    );
  }
}
