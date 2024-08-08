Active Directory est un produit Microsoft qui aide les administrateurs informatiques à gérer et à sécuriser les comptes d'utilisateurs, les systèmes et les autres ressources de leur réseau d'entreprise. Il peut notamment servir de fournisseur d'identité (IDP) et constitue un point d'accès unique aux différentes ressources accessibles via le réseau de l'entreprise.

Dans la pratique, Active Directory est décrit comme une base de données qui contient tous les utilisateurs, groupes et machines au sein de l'organisation. Active Directory permet donc entre autre, d'accéder aux données, aux applications, aux systèmes informatiques et aux périphériques. L'Active Directory nécessite par concequant une gestion rigoureuse des utilisateurs et de leurs autorisations. 

Relier un environnement Active Directory sur site à votre environnement d'applications bureautiques en cloud peut sembler une fonctionnalité de base, mais dans la pratique cela n'est pas si simple. L'IDP (Identity Provider) fonctionne sur site alors que de nombreuses applications auxquelles vous souhaitez vous connecter sont en fait hébergées dans le cloud. Il faut donc un agent spécialisé qui relie votre environnement sur site à vos applications en cloud, ce qui est indispensable en termes de sécurité, de fiabilité et de robustesse. Contrairement à de nombreuses solutions IAM concurrentes, HelloID peut connecter de manière transparente votre déploiement Active Directory sur site à vos applications cloud.

## Comment HelloID s'intègre à Active Directory

La solution de gestion des identités et des accès (IAM) HelloID dispose d'une interface standard avec Active Directory. HelloID automatise tous les processus de gestion des comptes d'utilisateurs et des droits d'accès dans Active Directory. La solution IAM s'appuie ici sur les informations du système de ressources humaines. 

Ci-dessous, nous examinons quelques-unes des options offertes par HelloID : 

**Création de nouveaux comptes d'utilisateurs et gestion des comptes existants**

Le personnel de chaque entreprise connaît une certaine rotation. Si on ajoute ou supprime un nouvel utilisateur de le système RH, HelloID transfère automatiquement cette information à Active Directory grâce à un lien vers ce système. C'est pratique, car cela garantit que toutes les informations contenues dans l'IDP sont parfaitement à jour et correspondent aux données du système RH. De plus, il n'est plus necessaire de créer manuellement les nouveaux comptes. Bien evidement HelloID corrèle les comptes existants.

Il suffit de décider si HelloID doit traiter les comptes existants (mise à jour d'attributs)ou si il ne doit gérer que les comptes nouvellement créés. Il s'agit d'une considération importante, car au fur et à mesure que les comptes vieillissent, les champs qui ont été remplis à la main peuvent devenir de plus en plus désynchronisés. Par exemple, lorsque les personnes changent de site ou de fonction, HelloID peut mettre à jour ces informations.

**Création, activation, désactivation et suppression d'utilisateurs**

Grâce à HelloID, il n'est plus necessaire de se soucier de la création, de l'activation et de la désactivation des comptes d'utilisateurs. HelloID peut également supprimer automatiquement des comptes d'Active Directory. Il est important de noter que HelloID ne supprime que l'utilisateur lui-même, mais ne touche pas aux ressources associées. Par exemple, un compte peut être associé à un répertoire personnel. Comme HelloID ne possède pas ces données, la solution IAM n'est pas légalement autorisée à les supprimer. Comme HelloID s'abstient de le faire, il assure d'être en conformité avec les lois et réglementations en vigueur et permet de garder le contrôle total des données.

**Attribution du bon nom d'utilisateur**

Lors de la création de comptes d'utilisateurs, il est important de choisir le bon nom d'utilisateur. Par exemple, inclure le nom et le prénom complets dans une adresse électronique, ou plutôt une combinaison d'initiales ou un nom de famille. En outre, comment gérer les doublons qui risquent de se produire dans les noms d'utilisateurs ? Grâce aux conventions de noms dans HelloID, ce processus est standardisé et garanti que les noms d'utilisateurs sont toujours construits de manière cohérente.

**Accorder ou refuser aux utilisateurs l'appartenance à un groupe**

La gestion des membres des groupes d'utilisateurs est un élément clé de la gestion des utilisateurs au sein de l'organisation. Grâce à ces appartenances à des groupes, il est possible d'attribuer facilement les autorisations adéquates aux utilisateurs. En règle générale, les autorisations sont définies pour un groupe d'utilisateurs en une seule fois, puis on assigne les utilisateurs à ce groupe. Grâce à l'intégration de HelloID avec Active Directory, vous il n'est plus necessaire de se soucier de ce processus et helloID assure que les utilisateurs se voient attribuer les bonnes autorisations de groupe et, si nécessaire, que les autorisations de groupe sont révoquées en temps voulu.

Il est important de noter que HelloID peut également créer automatiquement des groupes. Par exemple, si le département RH ajoute un nouveau département dans le système RH. Dans ce cas, HelloID reconnaît la création d'un nouveau département et attribue les membres appropriés sur cette base. C'est ce que nous appelons les autorisations dynamiques. À noter que dans ce cas, l'administrateur du système doit attribuer les groupes nouvellement créés aux ressources correspondantes.

**Personnaliser les attributs**

L'appartenance à un groupe dont un utilisateur a besoin dépend en partie de sa fonction. Dans une large mesure, on identifie cette fonction de manière automatisée. Pour ce faire, on utilise les attributs que HelloID extrait du système source (RH). On décide sur la base de quel attribut du système source on souhaite attribuer quels comptes et quels droits dans les systèmes cibles, qui dans ce cas est Active Directory. Cette méthode de travail est très pratique. Non seulement il n'est plus necessaire de se soucier d'identifier la fonction correcte d'un utilisateur, mais il est possible également être sûr que si la fonction d'un employé change, HelloID ajuste automatiquement ses comptes et ses droits si nécessaire. La plupart des systèmes source ont une structure dans laquelle un employé a un ou plusieurs contrats ou affectations. En fait, un employé peut avoir plusieurs fonctions. Sur la base de tous les rôles actifs, HelloID peut délivrer les autorisations correctes dans Active Directory.  

**Empêcher la réutilisation des adresses électroniques**

HelloID peut utiliser une liste noire qui empêche la réutilisation des adresses électroniques. Même si un compte d'utilisateur est libéré après une désactivation et que l'adresse électronique est techniquement réutilisable, la liste noire garantit que l'adresse électronique ne pourra jamais être émise à nouveau. C'est important car cela permet de s'assurer que le trafic de courrier électronique n'arrive jamais au mauvais destinataire et que, par exemple, les fichiers liés à une adresse électronique ne sont jamais accessibles involontairement à des personnes non autorisées. La même procédure peut d'ailleurs s'appliquer aux noms d'utilisateur.

**Unités organisationnelles**

Dans Active Directory, on travaille avec des dossiers, également appelés unités organisationnelles. Si par exemple l'organisation compte plusieurs succursales, il est possible de construire une structure de dossiers dans laquelle une disctinction est faite lentre ces branches et placer tous les dossiers des comptes liés dans le dossier de la branche appropriée. HelloID propose une méthode de travail structurée qui offre beaucoup de clarté et permet d'éviter les malentendus. Par exemple, HelloID peut créer automatiquement un dossier lors de la création d'un compte utilisateur, le déplacer dans le bon dossier de branche lorsque le compte est activé, par exemple, et le déplacer dans un dossier contenant des comptes désactivés lorsque le compte est désactivé.

**Interface avec Exchange**

Exchange est une extension d'Active Directory qui permet de gérer le trafic de courrier électronique. Le logiciel de Microsoft veille notamment à ce que les contacts, les éléments du calendrier et le courrier électronique soient disponibles sur tous les appareils d'un utilisateur. Pour ce faire, il s'appuie sur les informations d'Active Directory. HelloID peut s'interfacer avec Exchange, que le serveur Exchange fonctionne sur site ou dans le cloud. Vous n'utilisez pas Exchange, mais vous utilisez Exchange Online via des licences basées sur les groupes dans Azure ? HelloID peut également s'en charger. Il est important de noter que grâce à l'agent HelloID, les outils de gestion Exchange ne sont plus necessaires. Par conséquent, l'agent HelloID est léger et nécessite moins d'autorisations, ce qui est important du point de vue de la sécurité.. 

**Création d'un répertoire personnel et d'un répertoire de profil**

Pour le stockage des données, Active Directory utilise des dossiers personnels et des dossiers de profil. HelloID offre un support complet pour la création de ces dossiers. HelloID peut également gérer parfaitement toutes les permissions associées à ces dossiers pour vous. Pensez à archiver ces dossiers sur le même partage, par exemple dans un dossier appelé 'Archive'. Il est également possible d'ajouter un horodatage au nom du dossier. 

**Prise en charge des Post-actions**

HelloID prend en charge ce que l'on appelle les "post-actions". Il s'agit d'actions PowerShell que les administrateurs peuvent exécuter automatiquement une fois que HelloID a fait son travail. C'est pratique, car en tant qu'administrateur RH, vous travaillez souvent avec vos propres scripts que vous souhaitez exécuter dès que HelloID est prêt. Pensez à ajouter un texte comme "Activé par HelloID le [date]" à la description d'un compte AD après son activation par HelloID. Les post-actions sont possibles pour tout événement du cycle de vie exécuté par HelloID, comme l'activation, la désactivation ou la suppression d'un compte.

La particularité du lien entre HelloID et Active Directory est que, grâce à notre agent, il est possible de gérer des comptes Active Directory sur site depuis le Cloud. En tant que solution IDaaS, HelloID ne peut évidemment pas se contenter d'accéder au réseau interne de l'organisation. Toutes les actions sont executées par HelloID via un agent spécial dans le réseau. Ainsi, la communication avec HelloID se fait toujours à partir de l'agent et jamais à partir du Cloud.  Grâce à notre agent, une connexion transparente et surtout sécurisée est créée entre les deux systèmes. 

## HelloID for Active Directory vous aide à :

* **Accèder instantanément aux bonnes données et applications :** Les collaborateurs ont besoin d'accéder aux données et aux applications d'entreprise pour faire leur travail. Grâce au lien entre HelloID et Active Directory, vous pouvez être sûr que les nouveaux employés peuvent se mettre directement au travail dès leur premier jour.
* **Réaliser des gains de temps importants :** La gestion des comptes d'utilisateurs et des autorisations est un processus complexe et fastidieux, surtout si le nombre d'employés au sein de l'organisation augmente. Lier Active Directory à HelloID automatise ce processus dans une large mesure.
* **Réduire les erreurs humaines :** Il est humain de faire des erreurs, mais dans certains cas, elles peuvent avoir des conséquences importantes. Par exemple, l'oubli de révoquer les autorisations d'un utilisateur qui a quitté le service peut poser des problèmes par la suite, tant en termes de sécurité que de conformité. Grâce au lien entre Active Directory et HelloID, vous bénéficiez d'une sécurité dans ce domaine et minimisez le risque d'erreur humaine.
*  **Audits solides :** Le respect des procédures est automatique, enregistrant toutes les activités effectuées par HelloID en relation avec les utilisateurs et les autorisations. Vous avez ainsi toujours une vue d'ensemble complète et répondez à toutes les exigences en matière de conformité.

## Liaison d'Active Directory via HelloID avec les systèmes source et cible
Grâce à HelloID, vous pouvez relier Active Directory à un grand nombre d'autres systèmes. Les intégrations augmentent l'efficacité avec laquelle vous gérez les comptes d'utilisateurs et les droits d'accès. De cette manière, vous garantissez un environnement sûr et conforme, dans lequel vos employés sont productifs de manière optimale. Voici quelques exemples d'intégrations courantes :  

* **ADP - Lien avec Active Directory :** ADP est une solution RH très répandue. Grâce au lien ADP - Active Directory que vous pouvez créer avec HelloID, la solution IAM convertit automatiquement toutes les informations pertinentes de ce système RH en comptes d'utilisateurs et en droits d'accès dans Active Directory. 
* **CPAGE - Lien avec Active Directory :** Le logiciel de gestion des ressources humaines CPAGE permet d'automatiser tous les processus de gestion des ressources humaines, tant pour le personnel que pour les salaires. Mais vous souhaitez également que toutes les informations pertinentes dans CPAGE se retrouvent automatiquement dans Active Directory. Grâce au lien CPAGE - Active Directory que permet HelloID, vous n'avez pas à vous en soucier.
* **SAP - Lien avec Active Directory :**  SAP, dans le cadre de SAP Human Capital Management (HCM), offre plusieurs solutions qui soutiennent les RH dans leurs activités quotidiennes. Si vous utilisez SAP, vous voulez vous assurer que toutes les informations RH pertinentes sont automatiquement disponibles dans Active Directory. Grâce au lien SAP - Active Directory, vous en avez la certitude. 

Avec la prise en charge de plus de 200 connecteurs, HelloID facilite un large éventail d'intégrations entre Active Directory et d'autres systèmes. Pour répondre aux besoins en constante évolution des organisations, Tools4ever élargit continuellement sa gamme de connecteurs et d'intégrations.
