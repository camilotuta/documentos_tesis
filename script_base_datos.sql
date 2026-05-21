-- ─────────────────────────────────────────────────────────────────────────────
-- 0. EXTENSIONES Y CONFIGURACIÓN INICIAL
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. TIPOS ENUMERADOS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TYPE enum_estado_usuario AS ENUM (
    'Activo', 'Inactivo', 'Suspendido', 'Bloqueado'
);

CREATE TYPE enum_estado_viaje AS ENUM (
    'Creado', 'Programado', 'Iniciado', 'EnCurso', 'Pausado', 'Finalizado', 'Cancelado'
);

CREATE TYPE enum_estado_vehiculo AS ENUM (
    'Registrado', 'Disponible', 'EnUso', 'EnMantenimiento',
    'DocumentacionPendiente', 'FueraDeServicio'
);

CREATE TYPE enum_estado_monitoreo AS ENUM (
    'Configurando', 'Activo', 'Pausado', 'ModoOffline', 'Completado', 'Error'
);

CREATE TYPE enum_estado_alerta AS ENUM (
    'Detectada', 'Emitida', 'Atendida', 'NoAtendida', 'Escalada', 'Cerrada'
);

CREATE TYPE enum_tipo_alerta AS ENUM (
    'Fatiga', 'Somnolencia', 'Distraccion', 'PosturaCabeza', 'PatronConduccion'
);

CREATE TYPE enum_severidad_alerta AS ENUM (
    'Baja', 'Media', 'Alta', 'Critica'
);

CREATE TYPE enum_canal_notificacion AS ENUM (
    'Push', 'SMS', 'Email', 'WhatsApp'
);

CREATE TYPE enum_tipo_interaccion AS ENUM (
    'ComandoVoz', 'RespuestaAlerta', 'ConsultaAsistente', 'Recomendacion'
);

CREATE TYPE enum_nivel_permiso AS ENUM (
    'SinAcceso', 'SoloLectura', 'Configurar', 'AccesoCompleto'
);

CREATE TYPE enum_tipo_evento_auditoria AS ENUM (
    'Login', 'LoginFallido', 'Logout', 'CreacionRegistro', 'ModificacionRegistro',
    'EliminacionRegistro', 'ExportacionDatos', 'Escalamiento', 'CambioPermisos',
    'BloqueoUsuario', 'CambioContrasena', 'AccesoModulo'
);

CREATE TYPE enum_estado_modelo_ia AS ENUM (
    'Entrenando', 'Validando', 'Activo', 'Inactivo', 'Deprecado'
);

CREATE TYPE enum_estado_configuracion_ia AS ENUM (
    'Borrador', 'Activa', 'Inactiva'
);

CREATE TYPE enum_estado_ruta AS ENUM (
    'Activa', 'Inactiva', 'Suspendida'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. MÓDULO DE EMPRESA Y ORGANIZACIÓN
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE empresa (
    id_empresa      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nit             VARCHAR(20) NOT NULL UNIQUE,
    razon_social    VARCHAR(200) NOT NULL,
    nombre_comercial VARCHAR(200),
    direccion       VARCHAR(300),
    telefono        VARCHAR(20),
    email           VARCHAR(150),
    ciudad          VARCHAR(100),
    departamento    VARCHAR(100),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro  TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE sucursal (
    id_sucursal     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa      UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE CASCADE,
    nombre          VARCHAR(200) NOT NULL,
    direccion       VARCHAR(300),
    ciudad          VARCHAR(100),
    telefono        VARCHAR(20),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro  TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_empresa, nombre)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. MÓDULO DE ACCESO Y PERMISOS (RF-01, RNF-04, RNF-07)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE modulo_funcional (
    id_modulo       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo          VARCHAR(50) NOT NULL UNIQUE,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE rol (
    id_rol          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo          VARCHAR(50) NOT NULL UNIQUE,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     TEXT,
    es_superusuario BOOLEAN NOT NULL DEFAULT FALSE,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE permiso (
    id_permiso      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_rol          UUID NOT NULL REFERENCES rol(id_rol) ON DELETE CASCADE,
    id_modulo       UUID NOT NULL REFERENCES modulo_funcional(id_modulo) ON DELETE CASCADE,
    nivel           enum_nivel_permiso NOT NULL DEFAULT 'SinAcceso',
    fecha_asignacion TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_rol, id_modulo)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. MÓDULO DE USUARIOS (RF-02)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE usuario (
    id_usuario          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa          UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE RESTRICT,
    id_rol              UUID NOT NULL REFERENCES rol(id_rol) ON DELETE RESTRICT,
    id_sucursal         UUID REFERENCES sucursal(id_sucursal),
    username            VARCHAR(50) NOT NULL UNIQUE,
    email               VARCHAR(150) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    nombres             VARCHAR(100) NOT NULL,
    apellidos           VARCHAR(100) NOT NULL,
    tipo_documento      VARCHAR(5) NOT NULL DEFAULT 'CC',
    numero_documento    VARCHAR(20) NOT NULL UNIQUE,
    telefono            VARCHAR(20),
    estado              enum_estado_usuario NOT NULL DEFAULT 'Activo',
    intentos_fallidos   INTEGER NOT NULL DEFAULT 0,
    fecha_bloqueo       TIMESTAMP,
    ultimo_acceso       TIMESTAMP,
    acepta_habeas_data  BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_acepta_habeas TIMESTAMP,
    consentimiento_informado BOOLEAN NOT NULL DEFAULT FALSE,
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_usuario_empresa ON usuario(id_empresa);
CREATE INDEX idx_usuario_rol ON usuario(id_rol);
CREATE INDEX idx_usuario_estado ON usuario(estado);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. MÓDULO DE CONDUCTORES (extensión de Usuario)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE conductor (
    id_conductor        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario          UUID NOT NULL UNIQUE REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    numero_licencia     VARCHAR(30) NOT NULL,
    categoria_licencia  VARCHAR(10) NOT NULL,
    fecha_vencimiento_licencia DATE NOT NULL,
    grupo_sanguineo     VARCHAR(5),
    contacto_emergencia VARCHAR(200),
    telefono_emergencia VARCHAR(20),
    experiencia_anios   INTEGER DEFAULT 0,
    score_seguridad     DECIMAL(5,2) DEFAULT 100.00,
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conductor_usuario ON conductor(id_usuario);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. ASIGNACIÓN DE SUPERVISORES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE asignacion_supervisor (
    id_asignacion   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_supervisor   UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_conductor    UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    fecha_inicio    TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_fin       TIMESTAMP,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (id_supervisor, id_conductor, activo)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. MÓDULO DE VEHÍCULOS (RF-04, RF-05)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE tipo_vehiculo (
    id_tipo_vehiculo UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa       UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE CASCADE,
    nombre           VARCHAR(100) NOT NULL,
    descripcion      TEXT,
    capacidad_carga_kg DECIMAL(10,2),
    numero_ejes      INTEGER,
    activo           BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_empresa, nombre)
);

CREATE TABLE vehiculo (
    id_vehiculo         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa          UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE RESTRICT,
    id_tipo_vehiculo    UUID NOT NULL REFERENCES tipo_vehiculo(id_tipo_vehiculo) ON DELETE RESTRICT,
    placa               VARCHAR(10) NOT NULL UNIQUE,
    marca               VARCHAR(50),
    modelo              VARCHAR(50),
    anio                INTEGER,
    color               VARCHAR(30),
    numero_motor        VARCHAR(50),
    numero_chasis       VARCHAR(50),
    soat_numero         VARCHAR(50),
    soat_fecha_vencimiento DATE,
    rtm_numero          VARCHAR(50),
    rtm_fecha_vencimiento  DATE,
    tarjeta_operacion   VARCHAR(50),
    tarjeta_operacion_vencimiento DATE,
    estado              enum_estado_vehiculo NOT NULL DEFAULT 'Registrado',
    kilometraje_actual  DECIMAL(12,2) DEFAULT 0,
    gps_dispositivo_id  VARCHAR(100),
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_vehiculo_empresa ON vehiculo(id_empresa);
CREATE INDEX idx_vehiculo_estado ON vehiculo(estado);
CREATE INDEX idx_vehiculo_placa ON vehiculo(placa);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. MÓDULO DE RUTAS (RF-06, RF-07)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE catalogo_ruta (
    id_catalogo_ruta UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa       UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE CASCADE,
    nombre           VARCHAR(200) NOT NULL,
    origen           VARCHAR(200) NOT NULL,
    destino          VARCHAR(200) NOT NULL,
    origen_lat       DECIMAL(10,7),
    origen_lng       DECIMAL(10,7),
    destino_lat      DECIMAL(10,7),
    destino_lng      DECIMAL(10,7),
    distancia_km     DECIMAL(10,2),
    duracion_estimada_min INTEGER,
    puntos_intermedios JSONB,
    estado           enum_estado_ruta NOT NULL DEFAULT 'Activa',
    fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE ruta (
    id_ruta          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_catalogo_ruta UUID NOT NULL REFERENCES catalogo_ruta(id_catalogo_ruta) ON DELETE RESTRICT,
    id_conductor     UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE RESTRICT,
    id_vehiculo      UUID NOT NULL REFERENCES vehiculo(id_vehiculo) ON DELETE RESTRICT,
    fecha_programada DATE NOT NULL,
    hora_salida_estimada TIME,
    observaciones    TEXT,
    activo           BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ruta_conductor ON ruta(id_conductor);
CREATE INDEX idx_ruta_vehiculo ON ruta(id_vehiculo);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. MÓDULO DE VIAJES (RF-08)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE viaje (
    id_viaje            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_ruta             UUID NOT NULL REFERENCES ruta(id_ruta) ON DELETE RESTRICT,
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE RESTRICT,
    id_vehiculo         UUID NOT NULL REFERENCES vehiculo(id_vehiculo) ON DELETE RESTRICT,
    estado              enum_estado_viaje NOT NULL DEFAULT 'Creado',
    fecha_inicio        TIMESTAMP,
    fecha_fin           TIMESTAMP,
    duracion_total_min  INTEGER,
    distancia_recorrida_km DECIMAL(10,2),
    latitud_inicio      DECIMAL(10,7),
    longitud_inicio     DECIMAL(10,7),
    latitud_fin         DECIMAL(10,7),
    longitud_fin        DECIMAL(10,7),
    observaciones       TEXT,
    motivo_cancelacion  TEXT,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_viaje_conductor ON viaje(id_conductor);
CREATE INDEX idx_viaje_estado ON viaje(estado);
CREATE INDEX idx_viaje_fecha ON viaje(fecha_inicio);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. MÓDULO DE MONITOREO (RF-09)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE monitoreo_viaje (
    id_monitoreo        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL UNIQUE REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    estado              enum_estado_monitoreo NOT NULL DEFAULT 'Configurando',
    fps_captura         INTEGER NOT NULL DEFAULT 10,
    modelo_ia_version   VARCHAR(50),
    umbral_fatiga       DECIMAL(5,2) NOT NULL DEFAULT 0.70,
    umbral_somnolencia  DECIMAL(5,2) NOT NULL DEFAULT 0.75,
    umbral_distraccion  DECIMAL(5,2) NOT NULL DEFAULT 0.65,
    total_frames_analizados INTEGER DEFAULT 0,
    total_alertas_emitidas  INTEGER DEFAULT 0,
    score_fatiga_global DECIMAL(5,2) DEFAULT 0,
    latencia_promedio_ms INTEGER DEFAULT 0,
    parametros_empresa  JSONB,
    fecha_inicio        TIMESTAMP,
    fecha_fin           TIMESTAMP,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_monitoreo_viaje ON monitoreo_viaje(id_viaje);
CREATE INDEX idx_monitoreo_estado ON monitoreo_viaje(estado);

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. MÓDULO DE ALERTAS (RF-10, RF-11, RF-12)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE alerta (
    id_alerta           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    id_monitoreo        UUID NOT NULL REFERENCES monitoreo_viaje(id_monitoreo) ON DELETE CASCADE,
    tipo                enum_tipo_alerta NOT NULL,
    severidad           enum_severidad_alerta NOT NULL DEFAULT 'Media',
    estado              enum_estado_alerta NOT NULL DEFAULT 'Detectada',
    score_confianza     DECIMAL(5,4),
    descripcion         TEXT,
    latitud             DECIMAL(10,7),
    longitud            DECIMAL(10,7),
    timestamp_deteccion TIMESTAMP NOT NULL DEFAULT NOW(),
    timestamp_emision   TIMESTAMP,
    timestamp_respuesta TIMESTAMP,
    latencia_deteccion_ms INTEGER,
    fue_atendida        BOOLEAN DEFAULT FALSE,
    fue_escalada        BOOLEAN DEFAULT FALSE,
    tiempo_reaccion_seg DECIMAL(8,2),
    datos_sensor        JSONB,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alerta_viaje ON alerta(id_viaje);
CREATE INDEX idx_alerta_estado ON alerta(estado);
CREATE INDEX idx_alerta_tipo ON alerta(tipo);
CREATE INDEX idx_alerta_timestamp ON alerta(timestamp_deteccion);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. RESPUESTA DEL CONDUCTOR A ALERTAS (RF-13)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE respuesta_conductor (
    id_respuesta        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_alerta           UUID NOT NULL REFERENCES alerta(id_alerta) ON DELETE CASCADE,
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    tipo_respuesta      VARCHAR(50) NOT NULL,
    tiempo_respuesta_ms INTEGER,
    accion_tomada       TEXT,
    confirmada          BOOLEAN DEFAULT FALSE,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. NOTIFICACIONES AL SUPERVISOR (RF-12)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE notificacion_supervisor (
    id_notificacion     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_alerta           UUID NOT NULL REFERENCES alerta(id_alerta) ON DELETE CASCADE,
    id_supervisor       UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_viaje            UUID NOT NULL REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    canal               enum_canal_notificacion NOT NULL,
    mensaje             TEXT,
    fue_recibida        BOOLEAN DEFAULT FALSE,
    fue_respondida      BOOLEAN DEFAULT FALSE,
    accion_supervisor   TEXT,
    timestamp_envio     TIMESTAMP NOT NULL DEFAULT NOW(),
    timestamp_lectura   TIMESTAMP,
    timestamp_respuesta TIMESTAMP
);

CREATE INDEX idx_notif_supervisor ON notificacion_supervisor(id_supervisor);
CREATE INDEX idx_notif_alerta ON notificacion_supervisor(id_alerta);

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. EVENTOS DE FATIGA
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE evento_fatiga (
    id_evento           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    tipo_evento         VARCHAR(80) NOT NULL,
    nivel_severidad     enum_severidad_alerta NOT NULL,
    timestamp_evento    TIMESTAMP NOT NULL DEFAULT NOW(),
    duracion_seg        DECIMAL(8,2),
    datos_sensor_json   JSONB,
    latitud             DECIMAL(10,7),
    longitud            DECIMAL(10,7),
    asociado_alerta     UUID REFERENCES alerta(id_alerta)
);

CREATE INDEX idx_evento_viaje ON evento_fatiga(id_viaje);
CREATE INDEX idx_evento_conductor ON evento_fatiga(id_conductor);

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. PAUSAS ACTIVAS (RF-14)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE pausa_activa (
    id_pausa            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    id_monitoreo        UUID NOT NULL REFERENCES monitoreo_viaje(id_monitoreo) ON DELETE CASCADE,
    latitud             DECIMAL(10,7) NOT NULL,
    longitud            DECIMAL(10,7) NOT NULL,
    nombre_lugar        VARCHAR(200),
    ubicacion_segura    BOOLEAN NOT NULL DEFAULT TRUE,
    velocidad_al_pausar DECIMAL(6,2) DEFAULT 0,
    hora_inicio         TIMESTAMP NOT NULL DEFAULT NOW(),
    hora_fin            TIMESTAMP,
    duracion_min        DECIMAL(6,2),
    actividades_realizadas TEXT,
    geocoding_reverso   JSONB,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pausa_viaje ON pausa_activa(id_viaje);

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. INTERACCIONES DE VOZ (RF-13)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE interaccion_voz (
    id_interaccion      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    tipo                enum_tipo_interaccion NOT NULL,
    transcripcion_entrada TEXT,
    transcripcion_respuesta TEXT,
    idioma              VARCHAR(10) DEFAULT 'es',
    nivel_ruido_db      DECIMAL(5,2),
    confianza_reconocimiento DECIMAL(5,4),
    duracion_audio_seg  DECIMAL(6,2),
    texto_reconocido    TEXT,
    intencion_detectada VARCHAR(100),
    respuesta_generada  TEXT,
    exito_reconocimiento BOOLEAN DEFAULT TRUE,
    timestamp_interaccion TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_interaccion_viaje ON interaccion_voz(id_viaje);

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. ENCUESTAS SUS (RF-16)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE encuesta_sus (
    id_encuesta         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    pregunta_1          INTEGER CHECK (pregunta_1 BETWEEN 1 AND 5),
    pregunta_2          INTEGER CHECK (pregunta_2 BETWEEN 1 AND 5),
    pregunta_3          INTEGER CHECK (pregunta_3 BETWEEN 1 AND 5),
    pregunta_4          INTEGER CHECK (pregunta_4 BETWEEN 1 AND 5),
    pregunta_5          INTEGER CHECK (pregunta_5 BETWEEN 1 AND 5),
    pregunta_6          INTEGER CHECK (pregunta_6 BETWEEN 1 AND 5),
    pregunta_7          INTEGER CHECK (pregunta_7 BETWEEN 1 AND 5),
    pregunta_8          INTEGER CHECK (pregunta_8 BETWEEN 1 AND 5),
    pregunta_9          INTEGER CHECK (pregunta_9 BETWEEN 1 AND 5),
    pregunta_10         INTEGER CHECK (pregunta_10 BETWEEN 1 AND 5),
    score_sus           DECIMAL(5,2),
    comentarios         TEXT,
    completada          BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_encuesta_viaje ON encuesta_sus(id_viaje);
CREATE INDEX idx_encuesta_conductor ON encuesta_sus(id_conductor);

-- Trigger para cálculo automático del score SUS
CREATE OR REPLACE FUNCTION fn_calcular_score_sus()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pregunta_1 IS NOT NULL AND NEW.pregunta_2 IS NOT NULL
       AND NEW.pregunta_3 IS NOT NULL AND NEW.pregunta_4 IS NOT NULL
       AND NEW.pregunta_5 IS NOT NULL AND NEW.pregunta_6 IS NOT NULL
       AND NEW.pregunta_7 IS NOT NULL AND NEW.pregunta_8 IS NOT NULL
       AND NEW.pregunta_9 IS NOT NULL AND NEW.pregunta_10 IS NOT NULL THEN

        NEW.score_sus := (
            (NEW.pregunta_1 - 1) + (5 - NEW.pregunta_2) +
            (NEW.pregunta_3 - 1) + (5 - NEW.pregunta_4) +
            (NEW.pregunta_5 - 1) + (5 - NEW.pregunta_6) +
            (NEW.pregunta_7 - 1) + (5 - NEW.pregunta_8) +
            (NEW.pregunta_9 - 1) + (5 - NEW.pregunta_10)
        ) * 2.5;
        NEW.completada := TRUE;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_score_sus
    BEFORE INSERT OR UPDATE ON encuesta_sus
    FOR EACH ROW
    EXECUTE FUNCTION fn_calcular_score_sus();

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. MÉTRICAS DE VIAJE (RF-17)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE metrica_viaje (
    id_metrica          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_viaje            UUID NOT NULL UNIQUE REFERENCES viaje(id_viaje) ON DELETE CASCADE,
    total_alertas_fatiga    INTEGER DEFAULT 0,
    total_alertas_somnolencia INTEGER DEFAULT 0,
    total_alertas_distraccion INTEGER DEFAULT 0,
    total_alertas_emitidas  INTEGER DEFAULT 0,
    alertas_atendidas       INTEGER DEFAULT 0,
    alertas_escaladas       INTEGER DEFAULT 0,
    tiempo_reaccion_promedio_seg DECIMAL(8,2),
    total_pausas_activas    INTEGER DEFAULT 0,
    duracion_pausas_total_min DECIMAL(8,2) DEFAULT 0,
    score_seguridad         DECIMAL(5,2),
    porcentaje_atencion     DECIMAL(5,2),
    distancia_total_km      DECIMAL(10,2),
    duracion_conduccion_min INTEGER DEFAULT 0,
    velocidad_promedio_kmh  DECIMAL(6,2),
    fecha_calculo           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 19. MÉTRICAS DE DESEMPEÑO (consolidado por conductor)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE metrica_desempeno (
    id_metrica_desemp   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_conductor        UUID NOT NULL REFERENCES conductor(id_conductor) ON DELETE CASCADE,
    periodo_inicio      DATE NOT NULL,
    periodo_fin         DATE NOT NULL,
    total_viajes        INTEGER DEFAULT 0,
    total_km_recorridos DECIMAL(12,2) DEFAULT 0,
    total_horas_conduccion DECIMAL(8,2) DEFAULT 0,
    total_alertas_fatiga INTEGER DEFAULT 0,
    total_alertas_emitidas INTEGER DEFAULT 0,
    alertas_atendidas   INTEGER DEFAULT 0,
    alertas_escaladas   INTEGER DEFAULT 0,
    tiempo_reaccion_promedio DECIMAL(8,2),
    total_pausas_activas INTEGER DEFAULT 0,
    score_seguridad_promedio DECIMAL(5,2),
    score_sus_promedio  DECIMAL(5,2),
    fecha_calculo       TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_conductor, periodo_inicio, periodo_fin)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 20. MÓDULO DE INTELIGENCIA ARTIFICIAL (RF-18, RNF-01, RNF-02, RNF-06)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE modelo_ia (
    id_modelo           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre              VARCHAR(100) NOT NULL,
    version             VARCHAR(30) NOT NULL,
    tipo                VARCHAR(50) NOT NULL,
    descripcion         TEXT,
    ruta_archivo        VARCHAR(500),
    tamanio_mb          DECIMAL(8,2),
    f1_score            DECIMAL(5,4),
    precision_score     DECIMAL(5,4),
    recall_score        DECIMAL(5,4),
    estado              enum_estado_modelo_ia NOT NULL DEFAULT 'Entrenando',
    es_modelo_activo    BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_entrenamiento TIMESTAMP,
    fecha_despliegue    TIMESTAMP,
    parametros_entrenamiento JSONB,
    metricas_validacion JSONB,
    fecha_registro      TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (nombre, version)
);

CREATE TABLE configuracion_ia (
    id_configuracion    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa          UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE CASCADE,
    id_modelo           UUID REFERENCES modelo_ia(id_modelo),
    nombre              VARCHAR(100) NOT NULL,
    umbral_fatiga       DECIMAL(5,2) NOT NULL DEFAULT 0.70,
    umbral_somnolencia  DECIMAL(5,2) NOT NULL DEFAULT 0.75,
    umbral_distraccion  DECIMAL(5,2) NOT NULL DEFAULT 0.65,
    sensibilidad_alertas DECIMAL(5,2) NOT NULL DEFAULT 0.80,
    tiempo_escalamiento_seg INTEGER NOT NULL DEFAULT 120,
    fps_captura         INTEGER NOT NULL DEFAULT 10,
    intervalo_gps_seg   INTEGER NOT NULL DEFAULT 5,
    frecuencia_acelerometro_hz INTEGER NOT NULL DEFAULT 50,
    modo_offline_habilitado BOOLEAN NOT NULL DEFAULT TRUE,
    canales_notificacion JSONB DEFAULT '["Push","SMS"]',
    estado              enum_estado_configuracion_ia NOT NULL DEFAULT 'Borrador',
    modificado_por      UUID REFERENCES usuario(id_usuario),
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE parametro_ia (
    id_parametro        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_configuracion    UUID NOT NULL REFERENCES configuracion_ia(id_configuracion) ON DELETE CASCADE,
    clave               VARCHAR(100) NOT NULL,
    valor               VARCHAR(500) NOT NULL,
    tipo_dato           VARCHAR(30) NOT NULL DEFAULT 'string',
    descripcion         TEXT,
    UNIQUE (id_configuracion, clave)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 21. REPORTES BI (RF-15)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE reporte_bi (
    id_reporte          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_empresa          UUID NOT NULL REFERENCES empresa(id_empresa) ON DELETE CASCADE,
    generado_por        UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    tipo_reporte        VARCHAR(80) NOT NULL,
    titulo              VARCHAR(200) NOT NULL,
    periodo_inicio      DATE NOT NULL,
    periodo_fin         DATE NOT NULL,
    filtros_aplicados   JSONB,
    datos_consolidados  JSONB,
    kpis                JSONB,
    ruta_archivo_pdf    VARCHAR(500),
    url_descarga        VARCHAR(500),
    url_vigencia        TIMESTAMP,
    formato             VARCHAR(10) DEFAULT 'PDF',
    fecha_generacion    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 22. EXPORTACIÓN DE DATOS DE INVESTIGACIÓN
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE exportacion_datos (
    id_exportacion      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario          UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    tipo_exportacion    VARCHAR(50) NOT NULL,
    formato             VARCHAR(10) NOT NULL DEFAULT 'CSV',
    filtros             JSONB,
    variables_seleccionadas JSONB,
    anonimizado         BOOLEAN NOT NULL DEFAULT TRUE,
    total_registros     INTEGER DEFAULT 0,
    ruta_archivo        VARCHAR(500),
    cumple_habeas_data  BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_exportacion   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 23. MÓDULO DE SESIONES (RNF-04, RNF-07)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE sesion (
    id_sesion           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario          UUID NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    token_jwt           TEXT NOT NULL,
    ip_address          VARCHAR(45),
    user_agent          VARCHAR(500),
    dispositivo         VARCHAR(100),
    fecha_inicio        TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_expiracion    TIMESTAMP NOT NULL,
    fecha_cierre        TIMESTAMP,
    activa              BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_sesion_usuario ON sesion(id_usuario);
CREATE INDEX idx_sesion_activa ON sesion(activa);

-- ─────────────────────────────────────────────────────────────────────────────
-- 24. MÓDULO DE AUDITORÍA (RNF-05, RNF-07)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE auditoria (
    id_auditoria        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_usuario          UUID REFERENCES usuario(id_usuario) ON DELETE SET NULL,
    tipo_evento         enum_tipo_evento_auditoria NOT NULL,
    modulo              VARCHAR(80),
    tabla_afectada      VARCHAR(80),
    registro_id         UUID,
    accion              VARCHAR(30) NOT NULL,
    datos_anteriores    JSONB,
    datos_nuevos        JSONB,
    ip_address          VARCHAR(45),
    user_agent          VARCHAR(500),
    descripcion         TEXT,
    exitoso             BOOLEAN NOT NULL DEFAULT TRUE,
    timestamp_evento    TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auditoria_usuario ON auditoria(id_usuario);
CREATE INDEX idx_auditoria_tipo ON auditoria(tipo_evento);
CREATE INDEX idx_auditoria_fecha ON auditoria(timestamp_evento);
CREATE INDEX idx_auditoria_modulo ON auditoria(modulo);

-- =============================================================================
-- 25. DATOS INICIALES — MÓDULOS FUNCIONALES
-- =============================================================================

INSERT INTO modulo_funcional (codigo, nombre, descripcion) VALUES
    ('MOD_EMPLEADOS',       'Gestión de empleados',         'Registrar, editar y desactivar empleados.'),
    ('MOD_ROLES',           'Gestión de roles y perfiles',  'Definir y administrar roles y permisos del sistema.'),
    ('MOD_VEHICULOS',       'Gestión de vehículos',         'Registrar y administrar vehículos de la flota.'),
    ('MOD_VIAJES',          'Gestión de viajes',            'Crear, programar y gestionar viajes operativos.'),
    ('MOD_MONITOREO',       'Monitoreo IA / Alertas',       'Monitoreo en tiempo real y gestión de alertas de fatiga.'),
    ('MOD_REPORTES',        'Reportes BI',                  'Generación de informes con KPIs operativos y de seguridad.'),
    ('MOD_CONFIG_IA',       'Configuración de parámetros IA','Ajuste de umbrales, sensibilidad y modelos de IA.'),
    ('MOD_AUDITORIA',       'Auditoría del sistema',        'Consulta del registro completo de eventos de auditoría.'),
    ('MOD_EMPRESA',         'Gestión de empresa y flota',   'Administrar información corporativa y segmentar recursos.'),
    ('MOD_EXPORTACION',     'Exportar datos investigación', 'Exportación de datasets anonimizados para análisis.');

-- =============================================================================
-- 26. DATOS INICIALES — ROLES DEL SISTEMA
-- =============================================================================

INSERT INTO rol (codigo, nombre, descripcion, es_superusuario) VALUES
    ('ROL_CONDUCTOR',       'Conductor',                'Operador de vehículo de carga pesada. Usa el sistema durante viajes para monitoreo de seguridad e interacción por voz.',                   FALSE),
    ('ROL_COORD_EMPRESA',   'Coordinador de Empresa',   'Personal de la empresa responsable de gestionar la operación de la flota: empleados, vehículos, viajes y reportes consolidados.',        FALSE),
    ('ROL_SUPERVISOR',      'Supervisor de Flota',      'Personal operativo encargado de monitorear los viajes en curso y responder a eventos en tiempo real.',                                    FALSE),
    ('ROL_ADMIN_SISTEMA',   'Administrador del Sistema','Superusuario técnico-administrativo con acceso transversal a todos los módulos, gestión de empresas, roles y auditoría global.',         TRUE),
    ('ROL_INVESTIGADOR',    'Investigador UMB',         'Equipo de tesis y asesor académico. Accede a datos anonimizados, configura parámetros de IA y analiza resultados de investigación.',    FALSE);

-- =============================================================================
-- 27. DATOS INICIALES — MATRIZ DE PERMISOS POR ROL
-- =============================================================================
-- Leyenda: AccesoCompleto = ✓ | SoloLectura = L | Configurar = C | SinAcceso = ✗

-- ── Conductor ──
INSERT INTO permiso (id_rol, id_modulo, nivel) VALUES
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPLEADOS'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_ROLES'),        'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VEHICULOS'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VIAJES'),       'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_MONITOREO'),    'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_REPORTES'),     'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_CONFIG_IA'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_AUDITORIA'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPRESA'),      'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_CONDUCTOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EXPORTACION'),  'SinAcceso');

-- ── Coordinador de Empresa ──
INSERT INTO permiso (id_rol, id_modulo, nivel) VALUES
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPLEADOS'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_ROLES'),        'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VEHICULOS'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VIAJES'),       'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_MONITOREO'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_REPORTES'),     'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_CONFIG_IA'),    'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_AUDITORIA'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPRESA'),      'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_COORD_EMPRESA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EXPORTACION'),  'SinAcceso');

-- ── Supervisor de Flota ──
INSERT INTO permiso (id_rol, id_modulo, nivel) VALUES
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPLEADOS'),    'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_ROLES'),        'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VEHICULOS'),    'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VIAJES'),       'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_MONITOREO'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_REPORTES'),     'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_CONFIG_IA'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_AUDITORIA'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPRESA'),      'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_SUPERVISOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EXPORTACION'),  'SinAcceso');

-- ── Administrador del Sistema (Super Usuario) ──
INSERT INTO permiso (id_rol, id_modulo, nivel) VALUES
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPLEADOS'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_ROLES'),        'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VEHICULOS'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VIAJES'),       'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_MONITOREO'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_REPORTES'),     'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_CONFIG_IA'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_AUDITORIA'),    'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPRESA'),      'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_ADMIN_SISTEMA'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EXPORTACION'),  'SoloLectura');

-- ── Investigador UMB ──
INSERT INTO permiso (id_rol, id_modulo, nivel) VALUES
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPLEADOS'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_ROLES'),        'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VEHICULOS'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_VIAJES'),       'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_MONITOREO'),    'SoloLectura'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_REPORTES'),     'AccesoCompleto'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_CONFIG_IA'),    'Configurar'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_AUDITORIA'),    'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EMPRESA'),      'SinAcceso'),
    ((SELECT id_rol FROM rol WHERE codigo='ROL_INVESTIGADOR'), (SELECT id_modulo FROM modulo_funcional WHERE codigo='MOD_EXPORTACION'),  'AccesoCompleto');

-- =============================================================================
-- 28. FUNCIÓN DE VALIDACIÓN DE PERMISOS (middleware RBAC)
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_verificar_permiso(
    p_id_usuario UUID,
    p_codigo_modulo VARCHAR(50),
    p_nivel_requerido enum_nivel_permiso
) RETURNS BOOLEAN AS $$
DECLARE
    v_nivel_actual enum_nivel_permiso;
    v_es_superusuario BOOLEAN;
BEGIN
    -- Verificar si es superusuario (acceso total automático)
    SELECT r.es_superusuario INTO v_es_superusuario
    FROM usuario u
    JOIN rol r ON u.id_rol = r.id_rol
    WHERE u.id_usuario = p_id_usuario AND u.activo = TRUE AND u.estado = 'Activo';

    IF v_es_superusuario = TRUE THEN
        RETURN TRUE;
    END IF;

    -- Verificar permiso específico
    SELECT p.nivel INTO v_nivel_actual
    FROM permiso p
    JOIN modulo_funcional mf ON p.id_modulo = mf.id_modulo
    JOIN usuario u ON p.id_rol = u.id_rol
    WHERE u.id_usuario = p_id_usuario
      AND mf.codigo = p_codigo_modulo;

    IF v_nivel_actual IS NULL OR v_nivel_actual = 'SinAcceso' THEN
        RETURN FALSE;
    END IF;

    -- Jerarquía: AccesoCompleto > Configurar > SoloLectura > SinAcceso
    IF p_nivel_requerido = 'SoloLectura' THEN
        RETURN v_nivel_actual IN ('SoloLectura', 'Configurar', 'AccesoCompleto');
    ELSIF p_nivel_requerido = 'Configurar' THEN
        RETURN v_nivel_actual IN ('Configurar', 'AccesoCompleto');
    ELSIF p_nivel_requerido = 'AccesoCompleto' THEN
        RETURN v_nivel_actual = 'AccesoCompleto';
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 29. FUNCIÓN DE REGISTRO EN AUDITORÍA
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_registrar_auditoria(
    p_id_usuario UUID,
    p_tipo_evento enum_tipo_evento_auditoria,
    p_modulo VARCHAR(80),
    p_tabla VARCHAR(80),
    p_registro_id UUID,
    p_accion VARCHAR(30),
    p_datos_anteriores JSONB,
    p_datos_nuevos JSONB,
    p_ip VARCHAR(45),
    p_descripcion TEXT
) RETURNS UUID AS $$
DECLARE
    v_id_auditoria UUID;
BEGIN
    INSERT INTO auditoria (
        id_usuario, tipo_evento, modulo, tabla_afectada,
        registro_id, accion, datos_anteriores, datos_nuevos,
        ip_address, descripcion
    ) VALUES (
        p_id_usuario, p_tipo_evento, p_modulo, p_tabla,
        p_registro_id, p_accion, p_datos_anteriores, p_datos_nuevos,
        p_ip, p_descripcion
    ) RETURNING id_auditoria INTO v_id_auditoria;

    RETURN v_id_auditoria;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 30. FUNCIÓN DE BLOQUEO POR INTENTOS FALLIDOS
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_incrementar_intentos_fallidos(p_username VARCHAR(50))
RETURNS VOID AS $$
DECLARE
    v_intentos INTEGER;
BEGIN
    UPDATE usuario
    SET intentos_fallidos = intentos_fallidos + 1,
        fecha_actualizacion = NOW()
    WHERE username = p_username
    RETURNING intentos_fallidos INTO v_intentos;

    IF v_intentos >= 3 THEN
        UPDATE usuario
        SET estado = 'Suspendido',
            fecha_bloqueo = NOW()
        WHERE username = p_username;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_resetear_intentos(p_username VARCHAR(50))
RETURNS VOID AS $$
BEGIN
    UPDATE usuario
    SET intentos_fallidos = 0,
        fecha_bloqueo = NULL,
        ultimo_acceso = NOW()
    WHERE username = p_username;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 31. VISTAS ÚTILES
-- =============================================================================

-- Vista: Permisos completos por usuario
CREATE OR REPLACE VIEW vw_permisos_usuario AS
SELECT
    u.id_usuario,
    u.username,
    u.nombres || ' ' || u.apellidos AS nombre_completo,
    r.codigo AS codigo_rol,
    r.nombre AS nombre_rol,
    r.es_superusuario,
    mf.codigo AS codigo_modulo,
    mf.nombre AS nombre_modulo,
    p.nivel AS nivel_permiso
FROM usuario u
JOIN rol r ON u.id_rol = r.id_rol
LEFT JOIN permiso p ON r.id_rol = p.id_rol
LEFT JOIN modulo_funcional mf ON p.id_modulo = mf.id_modulo
WHERE u.activo = TRUE;

-- Vista: Dashboard del supervisor — viajes activos
CREATE OR REPLACE VIEW vw_viajes_activos AS
SELECT
    v.id_viaje,
    v.estado,
    v.fecha_inicio,
    c.id_conductor,
    u.nombres || ' ' || u.apellidos AS nombre_conductor,
    vh.placa,
    vh.marca || ' ' || vh.modelo AS vehiculo,
    cr.nombre AS nombre_ruta,
    cr.origen,
    cr.destino,
    mv.estado AS estado_monitoreo,
    mv.score_fatiga_global,
    mv.total_alertas_emitidas
FROM viaje v
JOIN conductor c ON v.id_conductor = c.id_conductor
JOIN usuario u ON c.id_usuario = u.id_usuario
JOIN vehiculo vh ON v.id_vehiculo = vh.id_vehiculo
JOIN ruta r ON v.id_ruta = r.id_ruta
JOIN catalogo_ruta cr ON r.id_catalogo_ruta = cr.id_catalogo_ruta
LEFT JOIN monitoreo_viaje mv ON v.id_viaje = mv.id_viaje
WHERE v.estado IN ('Iniciado', 'EnCurso', 'Pausado');

-- Vista: Matriz de permisos consolidada
CREATE OR REPLACE VIEW vw_matriz_permisos AS
SELECT
    r.nombre AS rol,
    r.codigo AS codigo_rol,
    mf.nombre AS modulo,
    mf.codigo AS codigo_modulo,
    p.nivel
FROM rol r
CROSS JOIN modulo_funcional mf
LEFT JOIN permiso p ON r.id_rol = p.id_rol AND mf.id_modulo = p.id_modulo
WHERE r.activo = TRUE AND mf.activo = TRUE
ORDER BY r.nombre, mf.nombre;

-- =============================================================================
-- FIN DEL SCRIPT
-- =============================================================================
