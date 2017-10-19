
//
// Definition for Probe service resources on Kubernetes.
//

// Import KSonnet library.
local k = import "ksonnet.beta.2/k.libsonnet";

// Short-cuts to various objects in the KSonnet library.
local depl = k.extensions.v1beta1.deployment;
local container = depl.mixin.spec.template.spec.containersType;
local containerPort = container.portsType;
local mount = container.volumeMountsType;
local volume = depl.mixin.spec.template.spec.volumesType;
local resources = container.resourcesType;
local env = container.envType;
local gceDisk = volume.mixin.gcePersistentDisk;
local svc = k.core.v1.service;
local svcPort = svc.mixin.spec.portsType;
local svcLabels = svc.mixin.metadata.labels;
local externalIp = svc.mixin.spec.loadBalancerIp;
local svcType = svc.mixin.spec.type;
local secretDisk = volume.mixin.secret;
local configMap = k.core.v1.configMap;

//
// This plays with some of the templating features of jsonnet.  We define the
// tls resources, and then define the open service by over-riding some of
// parameters.
//

// Resources for the probe-svc deployment, uses ETSI-over-TLS.
local tls(config) = {

    // Name used for the deployment and service.
    name: "probe-svc",
    cyberprobeVersion:: import "version.jsonnet",

    images: ["cybermaggedon/cyberprobe:" + self.cyberprobeVersion],

    local name = self.name,
    
    // Container ports used.
    ports:: [
        containerPort.newNamed("etsi-tls", 9001)
    ],

    // Volume mount points
    volumeMounts:: [
        mount.new("probe-svc-creds", "/key") + mount.readOnly(true),
        mount.new("cybermon-config", "/etc/cyberprobe/socket.lua") +
            mount.subPath("socket.lua") +
            mount.readOnly(true)
    ],

    // Environment variables
    local envs = [
        env.new("SOCKET_HOST", "analytics-input")
    ],

    // Command to execute in the container.
    command:: [
        "cybermon", "--port=9001", "--transport=tls", 
        "--config=/etc/cyberprobe/socket.lua", "--key=/key/key.probe",
        "--certificate=/key/cert.probe", "--trusted-ca=/key/cert.ca"],

    // Containers
    local containers = [
        container.new("cybermon", self.images[0]) +
            container.ports(self.ports) +
            container.command(self.command) +
            container.env(envs) +
            container.volumeMounts(self.volumeMounts) +
            container.mixin.resources.limits({
                memory: "256M", cpu: "1.0"
            }) +
            container.mixin.resources.requests({
                memory: "256M", cpu: "0.1"
            })
    ],

    // Volumes
    volumes:: [

        // probe-svc-creds secret
        volume.name("probe-svc-creds") +
            secretDisk.secretName("probe-svc-creds"),
        
        // socket.lua mapped in using a config map.
        volume.fromConfigMap("cybermon-config", "cybermon-config",
                             [{key: "socket.lua", path: "socket.lua"}])
        
    ],

    // Number of repliacs.
    replicas:: config.probeSvc,
    
    // Deployments
    deployments: [
        depl.new(name, self.replicas, containers,
                 {app: name, component: "access"}) +
            depl.mixin.spec.template.spec.volumes(self.volumes)
    ],

    // Ports used by the service.
    servicePorts:: [
        svcPort.newNamed("etsi-tls", 9001, 9001) + svcPort.protocol("TCP")
    ],

    // Public IP address of the service.
    externalAddress:: config.addresses.probeSvc,
    
    // Service
    services: [

        svc.new(name, {app: name}, self.servicePorts) +

           // Load-balancer and external IP address
           externalIp(self.externalAddress) + svcType("LoadBalancer") +

           // This traffic policy ensures observed IP addresses are the external
           // ones
           svc.mixin.spec.externalTrafficPolicy("Local") +

           // Label
           svcLabels({app: name, component: "access"})

    ],

    resources:
        if config.options.includeProbeSvc then
                self.deployments + self.services
        else [],

    // This is made up - it isn't used anywhere.  Just a demo of the idea
    // of adding information about builds to the cluster definition.
    buildSteps: [
        {
            resource: $.name,
            target: $.images[0],
            masterSource: "https://github.com/cybermaggedon/docker-cyberprobe",
            otherSources: [
                "https://github.com/cybermaggedon/cyberprobe"
            ],
            step: "container build and push"
        },
        {
            resource: $.name,
            target: "cyberprobe",
            masterSource: "https://github.com/cybermaggedon/cyberprobe",
            otherSources: [],
            step: "compile and release"
        }
    ],

    diagram: if config.options.includeProbeSvc then [
	"probesvc -> input",
	"probesvc [label=\"probe-svc\"]"
    ] else []
    
};

// Resources for the probe-svc-open deployment, uses ETSI-over-TCP.
local open(config) = tls(config) {

    // Over-ride deployment/service name.
    name: "probe-svc-open",
    local name = self.name,
    
    // Container ports used.
    ports:: [
        containerPort.newNamed("etsi", 9000)
    ],

    // Volume mount points
    volumeMounts:: [
        mount.new("cybermon-config", "/etc/cyberprobe/socket.lua") +
            mount.subPath("socket.lua") +
            mount.readOnly(true)
    ],

    // Command
    command:: [
        "cybermon", "--port=9000", "--transport=tcp", 
        "--config=/etc/cyberprobe/socket.lua"],

    // Volumes
    volumes:: [

        // socket.lua mapped in using a config map.
        volume.fromConfigMap("cybermon-config", "cybermon-config",
                             [{key: "socket.lua", path: "socket.lua"}])
        
    ],

    // Number of replicas
    replicas:: config.openProbeSvc,

    // External IP address
    externalAddress:: config.addresses.openProbeSvc,

    // Ports used by the service.
    servicePorts:: [
        svcPort.newNamed("etsi", 9000, 9000) + svcPort.protocol("TCP")
    ],

    resources:
        if config.options.includeOpenProbeSvc then
                self.deployments + self.services
        else [],

    diagram: if config.options.includeOpenProbeSvc then [
	"probesvcopen -> input",
	"probesvcopen [label=\"probe-svc-open\"]",
	"honeytraps -> probesvcopen",
	"honeytraps [label=\"Honey Traps\"]"
    ] else []
    
};

// CA
local ca(config) = {

    name: "probe-ca",
    images: ["gcr.io/trust-networks/probe-ca:0.03"],

    local name = self.name,

    // Environment
    local envs = [
        env.new("CA", "/ca"),
        env.new("CA_CERT", "/cert")
    ],

    // Volume mounts
    local volumeMounts = [
        mount.new("probe-ca-creds", "/cert") + mount.readOnly(true),
        mount.new("probe-ca-data", "/ca")
    ],

    // Containers
    local containers = [

        container.new(name, self.images[0]) +
            container.env(envs) +
            container.volumeMounts(volumeMounts) +
            container.mixin.resources.limits({
                memory: "32M", cpu: "1.0"
            }) +
            container.mixin.resources.requests({
                memory: "32M", cpu: "0.001"
            })
    ],

    // Volumes
    local volumes = [

        // probe-svc-creds secret
        volume.name("probe-ca-creds") +
            secretDisk.secretName("probe-ca-creds"),

        volume.name("probe-ca-data") + gceDisk.fsType("ext4") +
            gceDisk.pdName("probe-ca-0000")

    ],

    // Deployment definition.
    deployments:: [
            depl.new(name, 1, containers,
                     {app: name, component: "access"}) +
            depl.mixin.spec.template.spec.volumes(volumes)
    ],

    resources:
        if config.options.includeProbeSvc ||   
            config.options.includeOpenProbeSvc then
            self.deployments
        else [],

    createCommands:
        if config.options.includeProbeSvc ||   
            config.options.includeOpenProbeSvc then
            [
                ("gcloud compute --project \"%s\" disks create \"probe-ca-0000\"" +
                 " --size \"%s\" --zone \"%s\" --type \"%s\"") %
                    [config.project, config.probeCaDiskSize,
                     config.zone, config.probeCaDiskType]
            ]
        else []
};

local configMaps(config) = {

    name: "probe-config-maps",
    
    resources:
        if config.options.includeProbeSvc ||   
            config.options.includeOpenProbeSvc then [
            configMap.new() + configMap.mixin.metadata.name("cybermon-config") +
            configMap.data({"socket.lua": import "socket.lua.jsonnet"})
        ] else []
    
};
   
[tls, open, ca, configMaps]

