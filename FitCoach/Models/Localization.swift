import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "中文"
    case en = "English"
    case es = "Español"

    var id: String { rawValue }
    var shortLabel: String {
        switch self {
        case .zh: return "中"
        case .en: return "EN"
        case .es: return "ES"
        }
    }
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: raw) {
            language = lang
        } else {
            language = .zh
        }
    }

    func t(_ key: String) -> String {
        translations[key]?[language] ?? key
    }
}

private let translations: [String: [AppLanguage: String]] = [
    // Student list
    "我的学员": [.zh: "我的学员", .en: "My Clients", .es: "Mis Clientes"],
    "还没有学员": [.zh: "还没有学员", .en: "No clients yet", .es: "Aún no hay clientes"],
    "点击右上角 + 添加你的第一位学员": [
        .zh: "点击右上角 + 添加你的第一位学员",
        .en: "Tap + in the top right to add your first client",
        .es: "Toca el + para añadir tu primer cliente"
    ],
    "次训练": [.zh: "次训练", .en: "sessions", .es: "sesiones"],

    // Add student
    "添加学员": [.zh: "添加学员", .en: "Add Client", .es: "Añadir Cliente"],
    "基本资料": [.zh: "基本资料", .en: "Basic Info", .es: "Información Básica"],
    "姓名": [.zh: "姓名", .en: "Name", .es: "Nombre"],
    "性别": [.zh: "性别", .en: "Gender", .es: "Género"],
    "运动经验": [.zh: "运动经验", .en: "Experience", .es: "Experiencia"],
    "首次体测": [.zh: "首次体测", .en: "Initial Assessment", .es: "Evaluación Inicial"],
    "体重": [.zh: "体重", .en: "Weight", .es: "Peso"],
    "身高": [.zh: "身高", .en: "Height", .es: "Altura"],
    "体脂率": [.zh: "体脂率", .en: "Body Fat", .es: "Grasa Corporal"],
    "可选": [.zh: "可选", .en: "optional", .es: "opcional"],
    "臀围": [.zh: "臀围", .en: "Hips", .es: "Cadera"],
    "胸围": [.zh: "胸围", .en: "Chest", .es: "Pecho"],
    "腰围": [.zh: "腰围", .en: "Waist", .es: "Cintura"],
    "运动目标": [.zh: "运动目标", .en: "Goal", .es: "Objetivo"],
    "备注": [.zh: "备注", .en: "Notes", .es: "Notas"],
    "取消": [.zh: "取消", .en: "Cancel", .es: "Cancelar"],
    "保存学员": [.zh: "保存学员", .en: "Save Client", .es: "Guardar Cliente"],
    "年龄": [.zh: "年龄", .en: "Age", .es: "Edad"],
    "岁": [.zh: "岁", .en: "yo", .es: "años"],
    "例如：减脂、增肌、提升体能...": [
        .zh: "例如：减脂、增肌、提升体能...",
        .en: "e.g. fat loss, muscle gain, conditioning...",
        .es: "p. ej. perder grasa, ganar músculo, mejorar condición física..."
    ],
    "其他需要记录的信息": [
        .zh: "其他需要记录的信息",
        .en: "Any other notes worth keeping",
        .es: "Cualquier otra nota que quieras guardar"
    ],
    "例如 18.5": [.zh: "例如 18.5", .en: "e.g. 18.5", .es: "p. ej. 18.5"],
    "学员姓名": [.zh: "学员姓名", .en: "Client name", .es: "Nombre del cliente"],

    // Student detail
    "训练记录": [.zh: "训练记录", .en: "Sessions", .es: "Sesiones"],
    "还没有训练记录": [.zh: "还没有训练记录", .en: "No sessions yet", .es: "Aún no hay sesiones"],
    "新增训练计划": [.zh: "新增训练计划", .en: "New Session", .es: "Nueva Sesión"],
    "经验": [.zh: "经验", .en: "Level", .es: "Nivel"],

    // Add session
    "课程信息": [.zh: "课程信息", .en: "Session Info", .es: "Información de la Sesión"],
    "课程名称（可选）": [.zh: "课程名称（可选）", .en: "Title (optional)", .es: "Título (opcional)"],
    "日期": [.zh: "日期", .en: "Date", .es: "Fecha"],
    "训练计划": [.zh: "训练计划", .en: "Plan", .es: "Plan"],
    "还没有添加动作": [.zh: "还没有添加动作", .en: "No exercises added yet", .es: "Aún no hay ejercicios añadidos"],
    "添加动作": [.zh: "添加动作", .en: "Add Exercise", .es: "Añadir Ejercicio"],
    "保存计划": [.zh: "保存计划", .en: "Save Plan", .es: "Guardar Plan"],
    "动作名称，例如：杠铃深蹲": [
        .zh: "动作名称，例如：杠铃深蹲",
        .en: "Exercise name, e.g. Barbell Squat",
        .es: "Nombre del ejercicio, p. ej. Sentadilla con Barra"
    ],
    "动作名称": [.zh: "动作名称", .en: "Exercise Name", .es: "Nombre del Ejercicio"],
    "类型": [.zh: "类型", .en: "Category", .es: "Categoría"],
    "组数": [.zh: "组数", .en: "Sets", .es: "Series"],
    "每组次数": [.zh: "每组次数", .en: "Reps / set", .es: "Repeticiones / serie"],
    "组间间歇": [.zh: "组间间歇", .en: "Rest / set", .es: "Descanso / serie"],
    "计划完成时间": [.zh: "计划完成时间", .en: "Planned duration", .es: "Duración planificada"],
    "计划外动作": [.zh: "计划外动作", .en: "Extra Exercise", .es: "Ejercicio Extra"],
    "添加计划外动作": [.zh: "添加计划外动作", .en: "Add Extra Exercise", .es: "Añadir Ejercicio Extra"],
    "实际完成时间": [.zh: "实际完成时间", .en: "Actual duration", .es: "Duración real"],
    "分钟": [.zh: "分钟", .en: "min", .es: "min"],
    "秒": [.zh: "秒", .en: "sec", .es: "seg"],

    // Session detail
    "训练详情": [.zh: "训练详情", .en: "Session Detail", .es: "Detalle de la Sesión"],
    "已完成": [.zh: "已完成", .en: "Completed", .es: "Completado"],
    "进行中": [.zh: "进行中", .en: "In progress", .es: "En curso"],
    "计划": [.zh: "计划", .en: "Planned", .es: "Planeado"],
    "实际": [.zh: "实际", .en: "Actual", .es: "Real"],
    "次数": [.zh: "次数", .en: "Reps", .es: "Repeticiones"],
    "间歇(秒)": [.zh: "间歇(秒)", .en: "Rest (s)", .es: "Descanso (s)"],
    "时长(分)": [.zh: "时长(分)", .en: "Time (min)", .es: "Tiempo (min)"],
    "本次训练总消耗": [.zh: "本次训练总消耗", .en: "Total burned", .es: "Total quemado"],
    "本动作消耗": [.zh: "本动作消耗", .en: "Burned", .es: "Quemado"],

    // Exercise categories
    "力量训练": [.zh: "力量训练", .en: "Strength", .es: "Fuerza"],
    "有氧训练": [.zh: "有氧训练", .en: "Cardio Training", .es: "Entrenamiento Cardio"],
    "拉伸/柔韧": [.zh: "拉伸/柔韧", .en: "Stretching", .es: "Estiramiento"],
    "核心训练": [.zh: "核心训练", .en: "Core", .es: "Core"],
    "高强度间歇(HIIT)": [.zh: "高强度间歇(HIIT)", .en: "HIIT", .es: "HIIT"],

    // Cardio intensity
    "轻度有氧": [.zh: "轻度有氧", .en: "Light", .es: "Ligero"],
    "中度有氧": [.zh: "中度有氧", .en: "Moderate", .es: "Moderado"],
    "高度有氧": [.zh: "高度有氧", .en: "High", .es: "Alto"],
    "强度": [.zh: "强度", .en: "Intensity", .es: "Intensidad"],

    // Gender / level
    "男": [.zh: "男", .en: "Male", .es: "Hombre"],
    "女": [.zh: "女", .en: "Female", .es: "Mujer"],
    "其他": [.zh: "其他", .en: "Other", .es: "Otro"],
    "运动新手": [.zh: "运动新手", .en: "Beginner", .es: "Principiante"],
    "有一定基础": [.zh: "有一定基础", .en: "Intermediate", .es: "Intermedio"],
    "经验丰富": [.zh: "经验丰富", .en: "Advanced", .es: "Avanzado"],

    // Edit student
    "编辑资料": [.zh: "编辑资料", .en: "Edit Profile", .es: "Editar Perfil"],
    "完成": [.zh: "完成", .en: "Done", .es: "Listo"],
    "体重会实时用于计算训练消耗的卡路里，更新后所有训练记录会按最新体重重新计算。": [
        .zh: "体重会实时用于计算训练消耗的卡路里，更新后所有训练记录会按最新体重重新计算。",
        .en: "Weight feeds directly into the calorie calculation — update it and every session recalculates automatically.",
        .es: "El peso se usa en tiempo real para calcular las calorías quemadas — al actualizarlo, todas las sesiones se recalculan automáticamente."
    ],

    // Onboarding
    "欢迎使用": [.zh: "欢迎使用", .en: "Welcome", .es: "Bienvenido"],
    "先完善你自己的个人信息，之后就能记录你自己的训练日记了": [
        .zh: "先完善你自己的个人信息，之后就能记录你自己的训练日记了",
        .en: "Set up your own profile first — then you can start logging your own training journal",
        .es: "Primero completa tu propio perfil — luego podrás registrar tu propio diario de entrenamiento"
    ],
    "开始使用": [.zh: "开始使用", .en: "Get Started", .es: "Comenzar"],
    "完善个人信息": [.zh: "完善个人信息", .en: "Set Up Your Profile", .es: "Completa Tu Perfil"],

    // Session package / remaining sessions
    "课时包": [.zh: "课时包", .en: "Session Package", .es: "Paquete de Sesiones"],
    "总课时数": [.zh: "总课时数", .en: "Total Sessions", .es: "Sesiones Totales"],
    "节（不追踪课时可留空）": [
        .zh: "节（不追踪课时可留空）",
        .en: "sessions (leave blank to not track)",
        .es: "sesiones (dejar en blanco para no rastrear)"
    ],
    "剩余课时": [.zh: "剩余课时", .en: "Remaining", .es: "Restantes"],
    "续费后把总课时数改大即可，剩余课时会自动按已记录的训练次数重新计算。": [
        .zh: "续费后把总课时数改大即可，剩余课时会自动按已记录的训练次数重新计算。",
        .en: "When they renew, just increase the total — remaining sessions recalculate automatically from logged sessions.",
        .es: "Al renovar, solo aumenta el total — las sesiones restantes se recalculan automáticamente."
    ],

    // Settings / backup
    "设置": [.zh: "设置", .en: "Settings", .es: "Ajustes"],
    "数据备份": [.zh: "数据备份", .en: "Backup", .es: "Copia de Seguridad"],
    "导出数据": [.zh: "导出数据", .en: "Export Data", .es: "Exportar Datos"],
    "导入数据": [.zh: "导入数据", .en: "Import Data", .es: "Importar Datos"],
    "导出为一个文件，换手机或重装App后可以导入回来。": [
        .zh: "导出为一个文件，换手机或重装App后可以导入回来。",
        .en: "Export everything to a file — bring it back after switching phones or reinstalling.",
        .es: "Exporta todo a un archivo — recupéralo tras cambiar de teléfono o reinstalar."
    ],
    "导入会把备份文件里的学员和训练记录新增进来，不会覆盖或删除现有数据，注意避免重复导入同一份备份。": [
        .zh: "导入会把备份文件里的学员和训练记录新增进来，不会覆盖或删除现有数据，注意避免重复导入同一份备份。",
        .en: "Importing adds the clients and sessions from the backup file — it never overwrites or deletes existing data. Avoid importing the same backup twice.",
        .es: "Importar añade los clientes y sesiones del archivo — nunca sobrescribe ni elimina datos existentes. Evita importar la misma copia dos veces."
    ],
    "导入成功": [.zh: "导入成功", .en: "Import successful", .es: "Importación exitosa"],
    "导入失败": [.zh: "导入失败", .en: "Import failed", .es: "Error al importar"],
    "位学员": [.zh: "位学员", .en: "clients", .es: "clientes"]
]
