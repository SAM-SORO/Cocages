import 'dart:async';
import 'package:Gedcocanne/auth/services/login_services.dart';
import 'package:Gedcocanne/services/api/gespont_services.dart';
import 'package:Gedcocanne/services/api/table_canne_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';


class TableCanne extends StatefulWidget {
  //doit permettre de faire la recuperation des P2 et la synchro ainsi que le reset du timer dans le cas du pull to refresh
  final void Function() updateP2AndSyncAndResetTimer;
  //réçoit la liste des camions en attente de son papa
  final List<Map<String, String>> camionsAttente;
  //callback pour informer le parent lorsque la liste est modifier
  final Function(List<Map<String, String>>) onCamionsAttenteUpdated;
  //fonction pour recharger les camion en attente
  final Future<void> Function() chargerCamionsAttente;
  //booleen pour etre informer de si le chargement des camions en attente est terminer ou pas
  final bool isLoadingCamonAttente;
  

  const TableCanne({
    super.key, 
    required this.updateP2AndSyncAndResetTimer, 
    required this.onCamionsAttenteUpdated, 
    required this.chargerCamionsAttente,
    required this.camionsAttente, 
    required this.isLoadingCamonAttente,
  });

  @override
  State<TableCanne> createState() => _TableCanneState();
}

class _TableCanneState extends State<TableCanne> {
  // Liste des camions en attente
  //List<Map<String, String>> camionsAttente = [];
  // Liste des camions déjà déchargés
  List<Map<String, dynamic>> camionsDechargerTable = [];

  // Booléen pour suivre si le chargement des camions decharger dans les derniere heures est en cours ou pas
  late bool _isLoadingCamionDechager = true;
  
  Timer? _timer; // Variable pour stocker le Timer

  late String agentConnecter;

  // dictionnaire pour obtenir le nom associer au PN_CODE (type de canne)
  final Map<String, String> dictionnaire = {
    '1': 'CI',
    '2': 'CV',
    '3': 'CP'
  };
  

  //variable pour suiivre si une synchronisation est en cour ou pas avant de proceder a la mise a jour du POISP2 parceque 
  //Le Timer.periodic et le RefreshIndicator peuvent entrer en conflit si les deux tentent de mettre à jour les données en même temps
  bool _isSyncing = false;


  @override
  void initState() {
    super.initState();
    _chargerCamionsDechargerTableDerniereHeure(); // Charger les camions déchargés 
  }

  @override
  void dispose() {
    _timer?.cancel(); // Annuler le Timer lors de la destruction du widget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int nombreDeCamionEnAttente  = widget.camionsAttente.length ;

    return Scaffold(
      body: Row(
        children: <Widget>[
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCamionsAttente,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Camions en attente ($nombreDeCamionEnAttente)',
                      style:GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),

                    ),
                  ),
                  Expanded(
                    child: widget.isLoadingCamonAttente
                        ? const Center(child: CircularProgressIndicator()) // Afficher le CircularProgressIndicator si en chargement
                        : widget.camionsAttente.isEmpty
                            ? Center(
                                child: ListView(
                                  children: [
                                    const SizedBox(height: 50,),
                                    Text(
                                    'Aucun camion en attente',
                                    style: GoogleFonts.poppins(fontSize: 16),
                                    textAlign: TextAlign.center, // Centrer le texte horizontalement
                                  ),
                                  ],
                                ),
                              )

                            : ListView.builder(
                                itemCount: widget.camionsAttente.length,
                                itemBuilder: (context, index) {
                                  var camion = widget.camionsAttente[index];
                                  var datePremPeseeFormater = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(camion['PS_DATEHEUREP1']!));
                              
                                  //var typeCanne = dictionnaire[camion['TN_CODE']]
                                  return Dismissible(
                                    key: Key(camion['VE_CODE']!), // Clé unique pour chaque élément
                                    direction: DismissDirection.startToEnd,
                                    onDismissed: (direction) async {
                                      bool success = await _enregistrerCamionTable(camion, index); // Enregistrer le camion lors du glissement                                   
                                      if (success) await  _chargerCamionsDechargerTableDerniereHeure();
                                    },
                                    background: Container(
                                      color: Colors.green, // Couleur d'arrière-plan lors du glissement
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: const Icon(Icons.check, color: Colors.white),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.only(bottom: 15),
                                      margin: const EdgeInsets.only(left: 20),
                                      child: Card(
                                        //la couleurt du card en fonction de la technique de coupe
                                        color: camion['TN_CODE'] == '1' ? camion['PS_TECH_COUPE'] == 'RV' || camion['PS_TECH_COUPE'] == 'RB' ? const Color(0xFFF8E7E7) : Colors.white :  Colors.yellow,
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                          title: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '${camion['VE_CODE']} ',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '(${camion['PS_CODE']}) ',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '- ${camion['LIBELE_TYPECANNE']} - ${camion['PS_TECH_COUPE']}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text('poidsP1 : ${camion['PS_POIDSP1']} tonne, $datePremPeseeFormater', style: GoogleFonts.poppins(fontSize: 14)),
                                          ),
                                          leading: const Icon(Icons.fire_truck_rounded),
                                          trailing: Checkbox(
                                            value: false,
                                            onChanged: (bool? value) async {
                                              if (value == true) {
                                                bool success = await _enregistrerCamionTable(camion, index); // Enregistrer le camion si la case est cochée
                                                if (success) await  _chargerCamionsDechargerTableDerniereHeure();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 30),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCamionDechargerTable,
              child: _isLoadingCamionDechager
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Camion Déchargé sur la table à canne (${camionsDechargerTable.length})',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: camionsDechargerTable.isEmpty
                            ? Center(
                                child: ListView(
                                  children: [
                                    const SizedBox(height: 50),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            "Aucun camion déchargé récemment.",
                                            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              )
                            : ListView.builder(
                            itemCount: camionsDechargerTable.length,
                            itemBuilder: (context, index) {
                              var camion = camionsDechargerTable[index];
                              final dateDecharg = DateTime.parse(camion['dateHeureDecharg']);
                              final dateDechargFormated = DateFormat('dd/MM/yy HH:mm:ss').format(dateDecharg);
                              
                              // Vérification de l'autorisation : seul l'admin ou l'agent ayant effectué l'affectation peut annuler le déchargement
                              final agentDechargement = camion['agentMatricule']?.toString();
                              bool canCancelDechargement = agentConnecter == agentDechargement || agentConnecter == "admin";

                              return Dismissible(
                                key: Key(camion['veCode']),
                                direction: DismissDirection.endToStart ,
                                movementDuration: const Duration(seconds: 1),
                                confirmDismiss: (direction) async {
                                  // Vérifier l'autorisation avant de confirmer la suppression
                                  if (!canCancelDechargement) {
                                    // Si non autorisé, bloquer la suppression et afficher un message
                                    _showErrorMessage('Vous n\'avez pas l\'autorisation d\'annuler ce déchargement.', const Color(0xFF323232));
                                    return false; // Annule le geste de suppression
                                  }
                                  return true; // Permet la suppression si autorisé
                                },
                                onDismissed: (direction) async {
                                  if (canCancelDechargement) {
                                    // Appeler la fonction pour supprimer le camion et attendre le résultat
                                    bool success = await _supprimerCamionDechargerTable(camion['veCode'], camion['dateHeureDecharg']);
                                    
                                    // Supprimer l'élément de la liste locale si la suppression a réussi
                                    if (success) {
                                      setState(() {
                                        camionsDechargerTable.removeAt(index);
                                      });
                                      widget.chargerCamionsAttente();
                                    }
                                  } else {
                                    // l'action de suppression est visuellement annulée : l'élément est réinséré dans la liste sans être retiré. Cela se fait en appelant setState() pour redessiner l'interface, mais sans supprimer l'élément.
                                    // setState(() {
                                    //   // On force la réinsertion de l'élément sans le retirer
                                    // });                      
                                  }
                                },
                                background: Container(
                                  color: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.only(bottom: 15),
                                  //margin: const EdgeInsets.only(left: 20),
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                      title: Text(
                                        '${camion['veCode']} ( ${camion['parcelle']} ) - ${camion['libelleTypeCanne']} - ${camion['techCoupe']}',
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'poidsP1: ${camion['poidsP1']} tonnes, ${camion['poidsP2'] != null ? 'poidsP2: ${camion['poidsP2']} tonnes, ' : 'Poids Tare ${camion['poidsTare']} tonnes, '} poids Net: ${camion['poidsNet']} tonnes $dateDechargFormated',
                                          style: GoogleFonts.poppins(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        ),
                      ],
                    ),
            ),
          ),

        ],
      ),
      
    );
  }





  Future<void> _refreshCamionsAttente() async{
    widget.chargerCamionsAttente();
    widget.updateP2AndSyncAndResetTimer;
  }


  // Fonction pour récupérer les camions déchargés sur la table a canne
  Future<void> _chargerCamionsDechargerTableDerniereHeure() async {
    agentConnecter = (await getCurrentUserMatricule())!;
    try {
      final camions = await getCamionDechargerTableDerniereHeureFromAPI();
      
      setState(() {
        camionsDechargerTable = camions;
        _isLoadingCamionDechager = false;
      });
      widget.updateP2AndSyncAndResetTimer();

    } catch (err) {
      _showErrorMessage('Le chargement des camions déchargés à  échoué. Connectez vous au réseau.', const Color(0xFF323232));
    }
  }

 
  // pour éviter les conflits de mise a jour manuelle et automatique lorsque les deux se font au meme moment
  Future<void> _refreshCamionDechargerTable() async {
    //s'il n'ya pas de synchronisation
    if (!_isSyncing) {
      setState(() {
        _isSyncing = true;
      });
      //await _updtatePoidsP2();
      //await synchroniserDonnee;
      await _chargerCamionsDechargerTableDerniereHeure();
      widget.updateP2AndSyncAndResetTimer();

      setState(() {
        _isSyncing = false;
      });

      // _resetTimer(); // Réinitialiser le Timer après la mise à jour manuelle
    }
  }


  //enregistrer le camion via l'API en utilisant les informations fournies
  Future<bool> _enregistrerCamionTable(Map<String, String> camion, int index) async {
    try {
      // Extraire les informations du camion
      String veCode = camion['VE_CODE']!;
      double poidsP1 = double.parse(camion['PS_POIDSP1']!);
      String techCoupe = camion['PS_TECH_COUPE']!;
      String parcelle = camion['PS_CODE']!;
      String codeCanne = camion['TN_CODE']!;

      DateTime dateHeureP1 = DateTime.parse(camion['PS_DATEHEUREP1']!);
      String? matriculeAgent = await getCurrentUserMatricule();

      // Récupérer le poidsTare via l'API
      double? poidsTare = await recupererPoidsTare(veCode: veCode);

      if (poidsTare == null) {
        _showErrorMessage('Erreur: poidsTare introuvable pour $veCode', const Color(0xFF323232));
        // Afficher une notification ou un message d'erreur si le poidsTare est introuvable
        return false;
      }

      // Appeler l'API pour enregistrer le camion
      bool success = await saveDechargementTableFromAPI(
        veCode: veCode,
        poidsP1: poidsP1,
        techCoupe: techCoupe,
        parcelle: parcelle,
        dateHeureP1: dateHeureP1,
        poidsTare: poidsTare,
        matricule: matriculeAgent!,
        codeCanne: codeCanne
      );

      if (success) {
      // Mise à jour de l'état local : supprimer le camion de la liste
      setState(() {
        widget.camionsAttente.removeAt(index); // Supprimer le camion de la liste
      });

      // Appeler le callback pour informer le parent que la liste a changé
      widget.onCamionsAttenteUpdated(widget.camionsAttente);

      return true; // Enregistrement réussi
    } else {
      // Gérez l'échec d'enregistrement si nécessaire
      return false;
    }

    } catch (e) {
      // Gestion des erreurs
      _showErrorMessage('Erreur lors de l\'enregistrement du camion: $e', const Color(0xFF323232));
      return false;
    }
  }


  Future<bool> _supprimerCamionDechargerTable(String veCode, String dateHeureDecharg) async {
    bool success = await deleteCamionDechargerTableFromAPI(veCode, dateHeureDecharg);
    if (success) {
      // setState(() {
      //   camionsDechargerTable.removeWhere((camion) => camion['VE_CODE'] == veCode && camion['dateHeureDecharg'] == dateHeureDecharg);
      // });
      return true;
    } else {
      // Afficher un message d'erreur ou effectuer une autre action en cas d'échec
      _showErrorMessage('Erreur lors de la suppression du camion.', const Color(0xFF323232) );
      return false;
    }
  }


  // Fonction pour afficher les messages en precisant le temps que cela doit faire
  // void _showErrorMessage(String message, int milliseconds) {
  //   if (!mounted) return; // Si le widget est démonté, on arrête la méthode
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(message),
  //       duration: Duration(milliseconds: milliseconds),
  //     ),
  //   );
  // }

  
  void _showErrorMessage(String message, Color color) {
    //On déclare une variable pour stocker l'entrée de la notification.
    OverlaySupportEntry? entry;

    //On assigne l'entrée de la notification à cette variable.
    entry = showSimpleNotification(
      Row(
        children: [
          //const Icon(Icons.error, color: Colors.white), // Icône d'erreur
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              //On ferme la notification en appuyant sur la croix.
              entry?.dismiss(); // Fermer la notification via l'entrée
            },
          ),
        ],
      ),
      background: Colors.black, // Couleur de fond pour indiquer une erreur
      position: NotificationPosition.bottom,
      duration: const Duration(seconds: 4),
      slideDismissDirection: DismissDirection.horizontal, // Permet de glisser pour fermer
    );
  }


}
