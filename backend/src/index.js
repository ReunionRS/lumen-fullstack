import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import fsp from 'fs/promises';
import { randomUUID, createSign } from 'crypto';
import http2 from 'http2';
import { fileURLToPath } from 'url';
import { Pool } from 'pg';
import { authenticator } from 'otplib';
import mammoth from 'mammoth';
import nodemailer from 'nodemailer';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');
const UPLOADS_DIR = path.join(ROOT_DIR, 'uploads');
const DOCS_DIR = path.join(UPLOADS_DIR, 'documents');
const STAGE_PHOTOS_DIR = path.join(UPLOADS_DIR, 'stage-photos');
const AVATARS_DIR = path.join(UPLOADS_DIR, 'avatars');
const PROJECT_THUMBNAILS_DIR = path.join(UPLOADS_DIR, 'project-thumbnails');
const JOURNAL_PHOTOS_DIR = path.join(UPLOADS_DIR, 'journal-photos');

const {
  PORT = '4000',
  DATABASE_URL = 'postgresql://postgres:postgres@localhost:5432/crm_security',
  JWT_SECRET = 'dev_secret',
  CORS_ORIGIN = 'http://localhost:5173',
  ADMIN_EMAIL = 'admin@admin.ru',
  ADMIN_PASSWORD = 'admin123',
  ADMIN_FIO = 'Администратор',
  HA_BASE_URL = '',
  HA_TOKEN = '',
  FCM_PROJECT_ID = '',
  FCM_CLIENT_EMAIL = '',
  FCM_PRIVATE_KEY = '',
  APNS_KEY_ID = '',
  APNS_TEAM_ID = '',
  APNS_BUNDLE_ID = '',
  APNS_PRIVATE_KEY = '',
  APNS_USE_SANDBOX = 'false',
  HA_WEB_APP_URL = '',
  HA_WEB_REDIRECT_URIS = '',
  DEV_ALLOW_ALL_CORS = '',
  MAIL_ENABLED = 'false',
  MAIL_TRANSPORT = 'smtp',
  MAIL_FROM = 'Lumen Group <no-reply@cklumen.ru>',
  MAIL_REPLY_TO = '',
  MAIL_SENDMAIL_PATH = '/usr/sbin/sendmail',
  SMTP_HOST = '',
  SMTP_PORT = '587',
  SMTP_SECURE = 'false',
  SMTP_USER = '',
  SMTP_PASS = '',
  SMTP_REJECT_UNAUTHORIZED = 'true',
  APP_PUBLIC_URL = 'https://app.cklumen.ru',
} = process.env;

const pool = new Pool({ connectionString: DATABASE_URL });

const mailEnabled = String(MAIL_ENABLED || '').toLowerCase() === 'true';
let mailTransporter = null;

const htmlEscape = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const userRoleLabel = (role) => {
  switch (String(role || '').toLowerCase()) {
    case 'admin':
      return 'Администратор';
    case 'director':
      return 'Руководитель';
    case 'manager':
      return 'Менеджер';
    case 'foreman':
      return 'Прораб';
    case 'client':
      return 'Клиент';
    default:
      return role || 'Пользователь';
  }
};

const getMailTransporter = () => {
  if (!mailEnabled) return null;
  if (mailTransporter) return mailTransporter;

  if (String(MAIL_TRANSPORT || '').toLowerCase() === 'sendmail') {
    mailTransporter = nodemailer.createTransport({
      sendmail: true,
      newline: 'unix',
      path: MAIL_SENDMAIL_PATH || '/usr/sbin/sendmail',
    });
    return mailTransporter;
  }

  if (!SMTP_HOST) {
    console.warn('MAIL_ENABLED=true, but SMTP_HOST is empty. Welcome emails are disabled.');
    return null;
  }

  const auth =
    SMTP_USER && SMTP_PASS
      ? {
          user: SMTP_USER,
          pass: SMTP_PASS,
        }
      : undefined;

  mailTransporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT || 587),
    secure: String(SMTP_SECURE || '').toLowerCase() === 'true',
    auth,
    tls: {
      rejectUnauthorized:
        String(SMTP_REJECT_UNAUTHORIZED || '').toLowerCase() !== 'false',
    },
  });
  return mailTransporter;
};

const buildWelcomeEmail = ({ fio, email, password, role }) => {
  const roleLabel = userRoleLabel(role);
  const safeFio = htmlEscape(fio || 'Пользователь');
  const safeEmail = htmlEscape(email);
  const safePassword = htmlEscape(password);
  const safeRole = htmlEscape(roleLabel);
  const safeUrl = htmlEscape(APP_PUBLIC_URL);

  const text = [
    `Здравствуйте, ${fio || 'Пользователь'}!`,
    '',
    'Для вас создан аккаунт в Lumen Group.',
    '',
    `Ссылка: ${APP_PUBLIC_URL}`,
    `Email: ${email}`,
    `Пароль: ${password}`,
    `Роль: ${roleLabel}`,
    '',
    'После первого входа рекомендуем сменить пароль в профиле.',
  ].join('\n');

  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#111827">
      <h2 style="margin:0 0 12px">Добро пожаловать в Lumen Group</h2>
      <p>Здравствуйте, <b>${safeFio}</b>!</p>
      <p>Для вас создан аккаунт в системе Lumen Group.</p>
      <table style="border-collapse:collapse;margin:16px 0">
        <tr><td style="padding:6px 12px 6px 0;color:#6b7280">Ссылка</td><td style="padding:6px 0"><a href="${safeUrl}">${safeUrl}</a></td></tr>
        <tr><td style="padding:6px 12px 6px 0;color:#6b7280">Email</td><td style="padding:6px 0"><b>${safeEmail}</b></td></tr>
        <tr><td style="padding:6px 12px 6px 0;color:#6b7280">Пароль</td><td style="padding:6px 0"><b>${safePassword}</b></td></tr>
        <tr><td style="padding:6px 12px 6px 0;color:#6b7280">Роль</td><td style="padding:6px 0">${safeRole}</td></tr>
      </table>
      <p style="color:#6b7280">После первого входа рекомендуем сменить пароль в профиле.</p>
    </div>
  `;

  return { text, html };
};

const sendUserWelcomeEmail = async ({ fio, email, password, role }) => {
  const transporter = getMailTransporter();
  if (!transporter) return false;

  const { text, html } = buildWelcomeEmail({ fio, email, password, role });
  await transporter.sendMail({
    from: MAIL_FROM,
    to: email,
    replyTo: MAIL_REPLY_TO || undefined,
    subject: 'Доступ к Lumen Group',
    text,
    html,
  });
  return true;
};

const app = express();
const extraAllowedOrigins = [
  'http://localhost:5173',
  'http://localhost',
  'https://localhost',
  'capacitor://localhost',
  'ionic://localhost',
  'https://martstroyizhevskcrm.ru',
  'https://www.martstroyizhevskcrm.ru',
];

const allowedOrigins = new Set(
  String(CORS_ORIGIN || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean)
);
extraAllowedOrigins.forEach((origin) => allowedOrigins.add(origin));
const allowAllCors =
  String(DEV_ALLOW_ALL_CORS || '').toLowerCase() === 'true' ||
  String(process.env.NODE_ENV || '').toLowerCase() !== 'production';

const isLoopbackOrigin = (origin) => {
  try {
    const parsed = new URL(origin);
    return (
      parsed.hostname === 'localhost' ||
      parsed.hostname === '127.0.0.1' ||
      parsed.hostname === '::1'
    );
  } catch {
    return false;
  }
};

const isPrivateLanOrigin = (origin) => {
  try {
    const parsed = new URL(origin);
    const host = parsed.hostname;
    if (!host) return false;
    // Typical local-network ranges for dev devices.
    return (
      host.startsWith('192.168.') ||
      host.startsWith('10.') ||
      /^172\.(1[6-9]|2\d|3[0-1])\./.test(host)
    );
  } catch {
    return false;
  }
};

app.use(
  cors({
    credentials: true,
    origin(origin, callback) {
      if (allowAllCors) return callback(null, true);
      if (!origin) return callback(null, true);
      if (
        allowedOrigins.has(origin) ||
        isLoopbackOrigin(origin) ||
        isPrivateLanOrigin(origin)
      ) {
        return callback(null, true);
      }
      return callback(new Error('Not allowed by CORS'));
    },
  })
);
app.use(express.json({ limit: '10mb' }));
app.use('/uploads', express.static(UPLOADS_DIR));

// OAuth client metadata page for Home Assistant (IndieAuth requirement).
// Home Assistant reads this URL from `client_id` and validates redirect URI here.
app.get('/ha-oauth-client', (_req, res) => {
  const host = String(_req.headers.host || '').trim();
  const hostIp = host.includes(':') ? host.split(':')[0] : host;
  const webRedirectFromHost = host
    ? `http://${host}/ha-oauth-web-callback`
    : '';
  const webRedirect4100 = hostIp
    ? `http://${hostIp}:4100/ha-oauth-web-callback`
    : '';
  const extraRedirects = String(HA_WEB_REDIRECT_URIS || '')
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean)
    .map((url) => `<link rel="redirect_uri" href="${url}" />`)
    .join('\n    ');

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Lumen HA OAuth Client</title>
    <link rel="redirect_uri" href="lumenapp://ha-callback/oauth2redirect" />
    ${webRedirectFromHost ? `<link rel="redirect_uri" href="${webRedirectFromHost}" />` : ''}
    ${webRedirect4100 ? `<link rel="redirect_uri" href="${webRedirect4100}" />` : ''}
    <link rel="redirect_uri" href="http://192.168.0.109:4000/ha-oauth-web-callback" />
    ${extraRedirects}
  </head>
  <body>
    <h1>Lumen HA OAuth Client</h1>
    <p>This page is used by Home Assistant OAuth validation.</p>
  </body>
</html>`);
});

app.get('/ha-oauth-web-callback', (req, res) => {
  const host = String(req.headers.host || '').trim();
  const hostIp = host.includes(':') ? host.split(':')[0] : host;
  const fallbackWebAppUrl = hostIp
    ? `http://${hostIp}:5173`
    : 'http://localhost:5173';
  const targetBase = String(HA_WEB_APP_URL || fallbackWebAppUrl).replace(/\/$/, '');
  const query = new URLSearchParams();

  for (const [key, value] of Object.entries(req.query)) {
    if (Array.isArray(value)) {
      value.forEach((item) => query.append(key, String(item)));
    } else if (value != null) {
      query.set(key, String(value));
    }
  }

  const queryString = query.toString();
  res.redirect(302, `${targetBase}/ha-oauth-web-callback${queryString ? `?${queryString}` : ''}`);
});

[UPLOADS_DIR, DOCS_DIR, STAGE_PHOTOS_DIR, AVATARS_DIR, PROJECT_THUMBNAILS_DIR, JOURNAL_PHOTOS_DIR].forEach((dir) => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

const docStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, DOCS_DIR),
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${randomUUID()}${path.extname(file.originalname)}`),
});
const stagePhotoStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, STAGE_PHOTOS_DIR),
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${randomUUID()}${path.extname(file.originalname)}`),
});
const avatarStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, AVATARS_DIR),
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${randomUUID()}${path.extname(file.originalname)}`),
});
const projectThumbnailStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, PROJECT_THUMBNAILS_DIR),
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${randomUUID()}${path.extname(file.originalname)}`),
});
const journalPhotoStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, JOURNAL_PHOTOS_DIR),
  filename: (_req, file, cb) => cb(null, `${Date.now()}-${randomUUID()}${path.extname(file.originalname)}`),
});
const uploadDocument = multer({ storage: docStorage });
const uploadStagePhoto = multer({ storage: stagePhotoStorage });
const uploadAvatar = multer({ storage: avatarStorage });
const uploadProjectThumbnail = multer({ storage: projectThumbnailStorage });
const uploadJournalPhoto = multer({ storage: journalPhotoStorage });

const safeNum = (v, fallback = 0) => {
  const num = Number(v);
  return Number.isFinite(num) ? num : fallback;
};

const normalizeFilename = (value) => {
  const src = String(value || '');
  if (!src) return src;
  // Fix mojibake for UTF-8 names interpreted as latin1 by multipart parsers.
  if (/[ÐÑÃ]/.test(src)) {
    try {
      return Buffer.from(src, 'latin1').toString('utf8');
    } catch {
      return src;
    }
  }
  return src;
};

const filenameForContentDisposition = (value) => {
  const normalized = normalizeFilename(value) || 'file';
  const withoutCtl = normalized.replace(/[\r\n\t\0]+/g, ' ').trim();
  const withoutQuotes = withoutCtl.replace(/["\\]/g, '');
  const asciiFallback = withoutQuotes
    .replace(/[^\x20-\x7E]/g, '_')
    .replace(/\s+/g, ' ')
    .trim();
  return asciiFallback || 'file';
};

const escapeHtml = (value) =>
  String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const toProject = (row) => ({
  id: row.id,
  clientFio: row.client_fio,
  clientContacts: row.client_contacts || '',
  clientPhone: row.client_phone || '',
  clientEmail: row.client_email || '',
  clientUserId: row.client_user_id || undefined,
  constructionAddress: row.construction_address,
  thumbnailUrl: row.thumbnail_url || '',
  materials: row.materials || '',
  projectType: row.project_type,
  areaSqm: safeNum(row.area_sqm),
  estimatedCost: safeNum(row.estimated_cost),
  contractAmount: row.contract_amount == null ? undefined : safeNum(row.contract_amount),
  paidAmount: row.paid_amount == null ? undefined : safeNum(row.paid_amount),
  nextPaymentDate: row.next_payment_date || '',
  lastPaymentDate: row.last_payment_date || '',
  status: row.status,
  startDate: row.start_date || '',
  plannedEndDate: row.planned_end_date || '',
  actualEndDate: row.actual_end_date || '',
  cameraUrl: row.camera_url || '',
  stages: Array.isArray(row.stages) ? row.stages : [],
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

const toUser = (row) => ({
  uid: row.id,
  id: row.id,
  email: row.email,
  fio: row.fio,
  role: row.role,
  avatarUrl: row.avatar_url || '',
  twoFactorEnabled: row.two_factor_enabled === true,
  isActive: row.is_active !== false,
  isArchived: row.is_archived === true,
});

const toSupportMessage = (row) => ({
  id: row.id,
  clientUserId: row.client_user_id,
  messageText: row.message_text,
  isReadByAdmin: Boolean(row.is_read_by_admin),
  createdAt: row.created_at,
  senderId: row.sender_user_id,
  senderFio: row.sender_fio,
  senderRole: row.sender_role,
  clientFio: row.client_fio,
});

const toStageCommentNotification = (row) => ({
  id: row.id,
  clientUserId: row.client_user_id,
  projectId: row.project_id,
  projectAddress: row.project_address || '',
  stageId: row.stage_id,
  stageName: row.stage_name,
  commentText: row.comment_text,
  title: row.stage_name || 'Комментарий по этапу',
  body: row.comment_text || '',
  type: 'stage_comment',
  isRead: Boolean(row.is_read),
  createdAt: row.created_at,
});

const toSupportReplyNotification = (row) => ({
  id: `support-${row.id}`,
  clientUserId: row.client_user_id,
  projectId: '',
  projectAddress: 'Поддержка',
  stageId: 'support-chat',
  stageName: 'Поддержка',
  commentText: row.message_text || '',
  title: 'Ответ в чате поддержки',
  body: `${row.sender_fio || 'Сотрудник'}: ${row.message_text || ''}`,
  type: 'support_reply',
  isRead: true,
  createdAt: row.created_at,
});

const toSupportIncomingAdminNotification = (row) => ({
  id: `support-admin-${row.id}`,
  clientUserId: row.client_user_id,
  projectId: '',
  projectAddress: 'Поддержка',
  stageId: 'support-chat',
  stageName: 'Поддержка',
  commentText: row.message_text || '',
  title: 'Новое сообщение в поддержке',
  body: `${row.client_fio || 'Клиент'}: ${row.message_text || ''}`,
  type: 'support_incoming',
  isRead: Boolean(row.is_read_by_admin),
  createdAt: row.created_at,
});

const FINANCE_CATEGORIES = new Set(['construction', 'repair', 'maintenance', 'utilities']);

const toFinanceExpense = (row) => ({
  id: row.id,
  projectId: row.project_id,
  category: row.category,
  amount: safeNum(row.amount),
  date: row.expense_date,
  note: row.note || '',
  createdAt: row.created_at,
});

const toMaintenanceTask = (row) => ({
  id: row.id,
  projectId: row.project_id,
  projectAddress: row.project_address || '',
  clientUserId: row.client_user_id || '',
  title: row.title,
  notes: row.notes || '',
  scheduledDate: row.scheduled_date,
  status: row.status || 'scheduled',
  systemType: row.system_type || '',
  specialistName: row.specialist_name || '',
  reportNotes: row.report_notes || '',
  reportPhotoUrl: row.report_photo_url || '',
  createdAt: row.created_at,
  completedAt: row.completed_at,
});

const JOURNAL_ENTRY_TYPES = new Set(['repair', 'breakdown', 'maintenance', 'modernization']);

const toJournalEntry = (row) => ({
  id: row.id,
  projectId: row.project_id,
  projectAddress: row.project_address || '',
  clientUserId: row.client_user_id || '',
  entryType: row.entry_type,
  description: row.description || '',
  specialist: row.specialist || '',
  entryDate: row.entry_date,
  photoUrl: row.photo_url || '',
  createdAt: row.created_at,
});

const toMaintenanceNotification = (row) => ({
  id: `maintenance-${row.id}`,
  clientUserId: row.client_user_id || '',
  projectId: row.project_id,
  projectAddress: row.project_address || '',
  stageId: row.id,
  stageName: row.title || 'Плановое обслуживание',
  commentText: row.notes || '',
  title: row.title || 'Плановое обслуживание',
  body: row.notes || 'Запланировано обслуживание',
  type: 'maintenance',
  isRead: false,
  createdAt: row.scheduled_date,
});

const toMaintenanceRequestNotification = (row) => ({
  id: `maintenance-request-${row.id}`,
  clientUserId: row.client_user_id || '',
  projectId: row.project_id,
  projectAddress: row.project_address || '',
  stageId: row.id,
  stageName: 'Заявка на обслуживание',
  commentText: row.description || '',
  title: 'Новая заявка на обслуживание',
  body: row.description || row.system_type || 'Новая заявка',
  type: 'maintenance_request',
  isRead: false,
  createdAt: row.created_at,
});

const toMaintenanceRequest = (row) => ({
  id: row.id,
  projectId: row.project_id,
  projectAddress: row.project_address || '',
  clientUserId: row.client_user_id || '',
  taskId: row.task_id || '',
  systemType: row.system_type || '',
  description: row.description || '',
  preferredDate: row.preferred_date,
  specialistName: row.specialist_name || '',
  status: row.status || 'new',
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

const STAGE_STATUS_LABELS_RU = {
  not_started: 'Не начат',
  in_progress: 'В работе',
  completed: 'Завершён',
  overdue: 'Просрочен',
};

const stageStatusLabelRu = (value) => STAGE_STATUS_LABELS_RU[String(value || '').trim()] || String(value || '—');

const normalizeStageForCompare = (stage) => {
  const src = stage && typeof stage === 'object' ? stage : {};
  const photos = Array.isArray(src.photoUrls)
    ? src.photoUrls.map((x) => String(x || '').trim()).filter(Boolean)
    : [];
  return {
    id: String(src.id || '').trim(),
    name: String(src.name || '').trim(),
    status: String(src.status || '').trim(),
    plannedStart: String(src.plannedStart || '').trim(),
    plannedEnd: String(src.plannedEnd || '').trim(),
    stageComment: String(src.stageComment || '').trim(),
    comments: String(src.comments || '').trim(),
    photoUrls: photos,
  };
};

const normalizeExpenseDate = (value) => {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString().slice(0, 10);
};

const normalizeScheduledDate = normalizeExpenseDate;

const signToken = (user) =>
  jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });

const signTwoFactorPendingToken = (userId) =>
  jwt.sign({ id: userId, purpose: '2fa_pending' }, JWT_SECRET, { expiresIn: '10m' });

const verifyTwoFactorPendingToken = (token) => {
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    if (!payload || payload.purpose !== '2fa_pending' || !payload.id) return null;
    return String(payload.id);
  } catch {
    return null;
  }
};

const normalizeOtpCode = (value) => String(value || '').replace(/\s|-/g, '').trim();

const verifyTotpCode = (secret, code) => {
  if (!secret || !code) return false;
  try {
    return authenticator.verify({ token: code, secret, window: 1 });
  } catch {
    return false;
  }
};

const getUserFromToken = async (token) => {
  if (!token) return null;
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [payload.id]);
    if (!rows.length) return null;
    return toUser(rows[0]);
  } catch {
    return null;
  }
};

const getUserFromRequest = async (req) => {
  const auth = req.headers.authorization || '';
  const headerToken = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (headerToken) return getUserFromToken(headerToken);
  const queryToken = req.query.token ? String(req.query.token) : null;
  if (queryToken) return getUserFromToken(queryToken);
  return null;
};

const authRequired = async (req, res, next) => {
  try {
    const auth = req.headers.authorization || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'Unauthorized' });

    const payload = jwt.verify(token, JWT_SECRET);
    const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [payload.id]);
    if (!rows.length) return res.status(401).json({ error: 'Unauthorized' });

    req.user = toUser(rows[0]);
    next();
  } catch {
    return res.status(401).json({ error: 'Unauthorized' });
  }
};

const roleRequired = (...roles) => (req, res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  next();
};

const canAccessProject = (user, project) => user.role !== 'client' || project.clientUserId === user.id;

const hasFcmConfig = Boolean(FCM_PROJECT_ID && FCM_CLIENT_EMAIL && FCM_PRIVATE_KEY);
const hasApnsConfig = Boolean(APNS_KEY_ID && APNS_TEAM_ID && APNS_BUNDLE_ID && APNS_PRIVATE_KEY);
const apnsHost = String(APNS_USE_SANDBOX).toLowerCase() === 'true' ? 'api.sandbox.push.apple.com' : 'api.push.apple.com';

let cachedFcmAccessToken = '';
let cachedFcmAccessTokenExpMs = 0;
let cachedApnsJwt = '';
let cachedApnsJwtIatSec = 0;

const base64UrlEncode = (value) =>
  Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');

const normalizePem = (value) => String(value || '').replace(/\\n/g, '\n').trim();

const createServiceJwt = ({ clientEmail, privateKey, scope, tokenUri }) => {
  const nowSec = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: tokenUri,
    scope,
    iat: nowSec,
    exp: nowSec + 3600,
  };
  const headerPart = base64UrlEncode(JSON.stringify(header));
  const payloadPart = base64UrlEncode(JSON.stringify(payload));
  const toSign = `${headerPart}.${payloadPart}`;
  const signer = createSign('RSA-SHA256');
  signer.update(toSign);
  signer.end();
  const signature = signer.sign(normalizePem(privateKey));
  const signaturePart = base64UrlEncode(signature);
  return `${toSign}.${signaturePart}`;
};

const getFcmAccessToken = async () => {
  if (!hasFcmConfig) return '';
  const now = Date.now();
  if (cachedFcmAccessToken && cachedFcmAccessTokenExpMs - 60_000 > now) {
    return cachedFcmAccessToken;
  }

  const tokenUri = 'https://oauth2.googleapis.com/token';
  const assertion = createServiceJwt({
    clientEmail: FCM_CLIENT_EMAIL,
    privateKey: FCM_PRIVATE_KEY,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    tokenUri,
  });

  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`FCM auth failed: ${response.status}`);
  const json = await response.json();
  cachedFcmAccessToken = String(json.access_token || '');
  cachedFcmAccessTokenExpMs = now + Number(json.expires_in || 3600) * 1000;
  return cachedFcmAccessToken;
};

const sendFcmPush = async ({ token, title, body, data }) => {
  if (!hasFcmConfig || !token) return;
  const accessToken = await getFcmAccessToken();
  if (!accessToken) return;

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(FCM_PROJECT_ID)}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: String(title || ''), body: String(body || '') },
          data: Object.fromEntries(Object.entries(data || {}).map(([k, v]) => [k, String(v ?? '')])),
          android: { priority: 'high' },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            payload: { aps: { sound: 'default' } },
          },
        },
      }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`FCM push failed: ${response.status} ${text}`);
  }
};

const getApnsJwt = () => {
  const nowSec = Math.floor(Date.now() / 1000);
  if (cachedApnsJwt && nowSec - cachedApnsJwtIatSec < 50 * 60) return cachedApnsJwt;

  const header = { alg: 'ES256', kid: APNS_KEY_ID };
  const payload = { iss: APNS_TEAM_ID, iat: nowSec };
  const headerPart = base64UrlEncode(JSON.stringify(header));
  const payloadPart = base64UrlEncode(JSON.stringify(payload));
  const toSign = `${headerPart}.${payloadPart}`;
  const signer = createSign('sha256');
  signer.update(toSign);
  signer.end();
  const signature = signer.sign(normalizePem(APNS_PRIVATE_KEY));
  cachedApnsJwt = `${toSign}.${base64UrlEncode(signature)}`;
  cachedApnsJwtIatSec = nowSec;
  return cachedApnsJwt;
};

const sendApnsPush = ({ token, title, body, data }) =>
  new Promise((resolve, reject) => {
    if (!hasApnsConfig || !token) return resolve();
    const client = http2.connect(`https://${apnsHost}`);
    client.on('error', reject);

    const request = client.request({
      ':method': 'POST',
      ':path': `/3/device/${token}`,
      authorization: `bearer ${getApnsJwt()}`,
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
    });

    let raw = '';
    request.setEncoding('utf8');
    request.on('data', (chunk) => {
      raw += chunk;
    });
    request.on('response', (headers) => {
      const status = Number(headers[':status'] || 0);
      if (status >= 200 && status < 300) return;
      const msg = raw || headers.reason || `APNs status ${status}`;
      reject(new Error(`APNs push failed: ${msg}`));
    });
    request.on('end', () => {
      client.close();
      resolve();
    });
    request.on('error', (error) => {
      client.close();
      reject(error);
    });

    request.write(
      JSON.stringify({
        aps: {
          alert: { title: String(title || ''), body: String(body || '') },
          sound: 'default',
        },
        ...Object.fromEntries(Object.entries(data || {}).map(([k, v]) => [k, String(v ?? '')])),
      })
    );
    request.end();
  });

const sendPushToUsers = async ({ userIds, title, body, data = {} }) => {
  if (!Array.isArray(userIds) || !userIds.length) return;
  if (!title && !body) return;
  const normalizedUserIds = [...new Set(userIds.map((v) => String(v || '').trim()).filter(Boolean))];
  if (!normalizedUserIds.length) return;

  const placeholders = normalizedUserIds.map((_, i) => `$${i + 1}`).join(', ');
  const { rows } = await pool.query(
    `SELECT token, platform FROM user_push_tokens WHERE user_id IN (${placeholders})`,
    normalizedUserIds
  );

  const tasks = rows.map(async (row) => {
    const token = String(row.token || '').trim();
    const platform = String(row.platform || '').toLowerCase();
    if (!token) return;
    try {
      if (platform.includes('apns')) {
        await sendApnsPush({ token, title, body, data });
      } else {
        await sendFcmPush({ token, title, body, data });
      }
    } catch (error) {
      const message = String(error?.message || '');
      if (
        message.includes('registration-token-not-registered') ||
        message.includes('UNREGISTERED') ||
        message.includes('BadDeviceToken') ||
        message.includes('Unregistered')
      ) {
        await pool.query('DELETE FROM user_push_tokens WHERE token = $1', [token]);
      } else {
        console.warn('Push send failed:', message);
      }
    }
  });

  await Promise.all(tasks);
};

const normalizeHaBaseUrl = (value) => String(value || '').trim().replace(/\/+$/, '');
const haBaseUrl = normalizeHaBaseUrl(HA_BASE_URL);

const assertHaConfigured = () => {
  if (!haBaseUrl || !HA_TOKEN) {
    const error = new Error('Home Assistant integration is not configured');
    error.statusCode = 503;
    throw error;
  }
};

const getUserHaConnection = async (userId) => {
  const { rows } = await pool.query(
    `SELECT *
     FROM home_assistant_connections
     WHERE user_id = $1
     ORDER BY updated_at DESC
     LIMIT 1`,
    [userId]
  );
  return rows[0] || null;
};

const toQueryString = (params) => {
  const sp = new URLSearchParams();
  for (const [key, value] of Object.entries(params || {})) {
    if (value == null || value === '') continue;
    sp.set(key, String(value));
  }
  const query = sp.toString();
  return query ? `?${query}` : '';
};

const haRequest = async ({ method = 'GET', path: endpointPath, query, body }) => {
  assertHaConfigured();
  const url = `${haBaseUrl}${endpointPath}${toQueryString(query)}`;

  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${HA_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = { raw: text };
    }
  }

  if (!response.ok) {
    const message =
      payload?.message ||
      payload?.error ||
      `Home Assistant request failed with status ${response.status}`;
    const error = new Error(message);
    error.statusCode = response.status;
    error.payload = payload;
    throw error;
  }

  return payload;
};

const refreshUserHaToken = async (connection) => {
  const baseUrl = normalizeHaBaseUrl(connection.base_url);
  const refreshToken = String(connection.refresh_token || '').trim();
  const clientId = String(connection.client_id || '').trim();
  if (!baseUrl || !refreshToken || !clientId) return null;

  const response = await fetch(`${baseUrl}/auth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: clientId,
    }),
  });
  if (!response.ok) return null;
  const json = await response.json();
  const accessToken = String(json.access_token || '').trim();
  const nextRefresh = String(json.refresh_token || refreshToken).trim();
  const expiresIn = Number(json.expires_in || 0);
  if (!accessToken || !nextRefresh || !Number.isFinite(expiresIn) || expiresIn <= 0) {
    return null;
  }

  const expiresAt = new Date(Date.now() + expiresIn * 1000);
  await pool.query(
    `UPDATE home_assistant_connections
     SET access_token = $2,
         refresh_token = $3,
         expires_at = $4,
         last_checked_at = NOW(),
         updated_at = NOW()
     WHERE id = $1`,
    [connection.id, accessToken, nextRefresh, expiresAt.toISOString()]
  );

  return {
    ...connection,
    access_token: accessToken,
    refresh_token: nextRefresh,
    expires_at: expiresAt.toISOString(),
  };
};

const haRequestForUser = async (userId, options) => {
  const connection = await getUserHaConnection(userId);
  if (!connection) {
    return haRequest(options);
  }

  const callWithToken = async (token) => {
    const url = `${normalizeHaBaseUrl(connection.base_url)}${options.path}${toQueryString(options.query)}`;
    const response = await fetch(url, {
      method: options.method || 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: options.body == null ? undefined : JSON.stringify(options.body),
    });

    const text = await response.text();
    let payload = null;
    if (text) {
      try {
        payload = JSON.parse(text);
      } catch {
        payload = { raw: text };
      }
    }
    return { response, payload };
  };

  let current = connection;
  let { response, payload } = await callWithToken(String(current.access_token || ''));
  if (response.status === 401) {
    const refreshed = await refreshUserHaToken(current);
    if (refreshed) {
      current = refreshed;
      ({ response, payload } = await callWithToken(String(current.access_token || '')));
    }
  }

  if (!response.ok) {
    const message =
      payload?.message ||
      payload?.error ||
      `Home Assistant request failed with status ${response.status}`;
    const error = new Error(message);
    error.statusCode = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
};

const parseHoursWindow = (rawValue, fallback = 24) => {
  const n = Number(rawValue);
  if (!Number.isFinite(n)) return fallback;
  if (n < 1) return 1;
  if (n > 168) return 168;
  return Math.floor(n);
};

const requireProjectAccess = async (user, projectId) => {
  const { rows } = await pool.query('SELECT * FROM projects WHERE id = $1 LIMIT 1', [projectId]);
  if (!rows.length) {
    const error = new Error('Объект не найден');
    error.statusCode = 404;
    throw error;
  }
  const project = toProject(rows[0]);
  if (!canAccessProject(user, project)) {
    const error = new Error('Forbidden');
    error.statusCode = 403;
    throw error;
  }
  return project;
};

const resolveProjectClientUserId = async (project) => {
  const direct = String(project?.clientUserId || '').trim();
  if (direct) return direct;

  const email = String(project?.clientEmail || '').trim().toLowerCase();
  if (email) {
    const { rows } = await pool.query(
      `SELECT id FROM users
       WHERE role = 'client' AND lower(email) = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [email]
    );
    if (rows.length) return String(rows[0].id || '');
  }

  const fio = String(project?.clientFio || '').trim();
  if (fio) {
    const { rows } = await pool.query(
      `SELECT id FROM users
       WHERE role = 'client' AND fio = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [fio]
    );
    if (rows.length) return String(rows[0].id || '');
  }

  return '';
};

const bootstrap = async () => {
  await fsp.mkdir(DOCS_DIR, { recursive: true });
  await fsp.mkdir(STAGE_PHOTOS_DIR, { recursive: true });

  const schemaSql = await fsp.readFile(path.join(__dirname, 'schema.sql'), 'utf8');
  await pool.query(schemaSql);

  const { rows } = await pool.query('SELECT id FROM users WHERE email = $1 LIMIT 1', [ADMIN_EMAIL.toLowerCase()]);
  if (!rows.length) {
    const passwordHash = await bcrypt.hash(ADMIN_PASSWORD, 10);
    await pool.query(
      'INSERT INTO users (id, email, password_hash, fio, role) VALUES ($1, $2, $3, $4, $5)',
      [randomUUID(), ADMIN_EMAIL.toLowerCase(), passwordHash, ADMIN_FIO, 'admin']
    );
    console.log(`Admin user created: ${ADMIN_EMAIL}`);
  }
};

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.get('/api/mail/status', authRequired, roleRequired('admin', 'director'), (_req, res) => {
  res.json({
    enabled: mailEnabled,
    transport: MAIL_TRANSPORT,
    from: MAIL_FROM,
    smtpHost: SMTP_HOST || null,
    sendmailPath:
      String(MAIL_TRANSPORT || '').toLowerCase() === 'sendmail'
        ? MAIL_SENDMAIL_PATH
        : null,
  });
});

app.post('/api/mail/test', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const email = String(req.body.email || req.user.email || '').trim().toLowerCase();
    if (!email) return res.status(400).json({ error: 'email обязателен' });
    const sent = await sendUserWelcomeEmail({
      fio: req.user.fio || 'Пользователь',
      email,
      password: 'test-password',
      role: req.user.role,
    });
    if (!sent) {
      return res.status(503).json({ error: 'Почта не настроена' });
    }
    res.json({ ok: true });
  } catch (error) {
    console.warn('Failed to send test email:', error?.message || error);
    res.status(500).json({ error: 'Не удалось отправить тестовое письмо' });
  }
});

app.get('/api/home-assistant/connection', authRequired, async (req, res) => {
  try {
    const connection = await getUserHaConnection(req.user.id);
    if (!connection) return res.json({ connected: false });
    return res.json({
      connected: true,
      item: {
        id: connection.id,
        userId: connection.user_id,
        houseId: connection.house_id || '',
        baseUrl: connection.base_url,
        expiresAt: connection.expires_at,
        status: connection.status || 'connected',
        lastCheckedAt: connection.last_checked_at,
      },
    });
  } catch {
    return res.status(500).json({ error: 'Не удалось получить подключение Home Assistant' });
  }
});

app.post('/api/home-assistant/connection', authRequired, async (req, res) => {
  try {
    const baseUrl = normalizeHaBaseUrl(req.body.baseUrl);
    const accessToken = String(req.body.accessToken || '').trim();
    const refreshToken = String(req.body.refreshToken || '').trim();
    const clientId = String(req.body.clientId || '').trim();
    const houseId = String(req.body.houseId || '').trim();
    const status = String(req.body.status || 'connected').trim() || 'connected';
    const expiresAtRaw = String(req.body.expiresAt || '').trim();
    const parsedExp = new Date(expiresAtRaw);
    if (!baseUrl || !accessToken || !refreshToken || !clientId || Number.isNaN(parsedExp.getTime())) {
      return res.status(400).json({ error: 'Некорректные данные подключения Home Assistant' });
    }

    const id = randomUUID();
    await pool.query(
      `INSERT INTO home_assistant_connections (
         id, user_id, house_id, base_url, access_token, refresh_token, client_id, expires_at, status, last_checked_at, updated_at
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,NOW(),NOW())
       ON CONFLICT (user_id) DO UPDATE SET
         house_id = EXCLUDED.house_id,
         base_url = EXCLUDED.base_url,
         access_token = EXCLUDED.access_token,
         refresh_token = EXCLUDED.refresh_token,
         client_id = EXCLUDED.client_id,
         expires_at = EXCLUDED.expires_at,
         status = EXCLUDED.status,
         last_checked_at = NOW(),
         updated_at = NOW()`,
      [
        id,
        req.user.id,
        houseId || null,
        baseUrl,
        accessToken,
        refreshToken,
        clientId,
        parsedExp.toISOString(),
        status,
      ]
    );

    return res.json({ ok: true });
  } catch {
    return res.status(500).json({ error: 'Не удалось сохранить подключение Home Assistant' });
  }
});

app.delete('/api/home-assistant/connection', authRequired, async (req, res) => {
  try {
    await pool.query('DELETE FROM home_assistant_connections WHERE user_id = $1', [req.user.id]);
    return res.json({ ok: true });
  } catch {
    return res.status(500).json({ error: 'Не удалось удалить подключение Home Assistant' });
  }
});

app.get('/api/systems/status', authRequired, async (req, res) => {
  try {
    const projectId = String(req.query.projectId || '').trim();
    if (projectId) {
      await requireProjectAccess(req.user, projectId);
    } else if (req.user.role === 'client') {
      return res.status(400).json({ error: 'projectId обязателен для клиента' });
    }

    const states = await haRequestForUser(req.user.id, { path: '/api/states' });
    const domain = String(req.query.domain || '').trim().toLowerCase();
    const filtered = Array.isArray(states)
      ? states.filter((item) => {
          if (!domain) return true;
          return String(item?.entity_id || '').toLowerCase().startsWith(`${domain}.`);
        })
      : [];

    const normalized = filtered.map((item) => ({
      entityId: item?.entity_id || '',
      domain: String(item?.entity_id || '').split('.')[0] || '',
      state: item?.state ?? '',
      friendlyName: item?.attributes?.friendly_name || item?.entity_id || '',
      unit: item?.attributes?.unit_of_measurement || '',
      deviceClass: item?.attributes?.device_class || '',
      icon: item?.attributes?.icon || '',
      lastChanged: item?.last_changed || '',
      lastUpdated: item?.last_updated || '',
      attributes: item?.attributes || {},
    }));

    res.json({
      projectId: projectId || null,
      count: normalized.length,
      items: normalized,
    });
  } catch (error) {
    const upstreamStatus = Number(error.statusCode || 0);
    const status = upstreamStatus === 401 ? 502 : (upstreamStatus || 500);
    res.status(status).json({
      error: error.message || 'Ошибка получения данных систем',
      source: upstreamStatus === 401 ? 'home_assistant_auth' : 'server',
      details: error.payload || null,
    });
  }
});

app.get('/api/systems/history', authRequired, async (req, res) => {
  try {
    const projectId = String(req.query.projectId || '').trim();
    if (projectId) {
      await requireProjectAccess(req.user, projectId);
    } else if (req.user.role === 'client') {
      return res.status(400).json({ error: 'projectId обязателен для клиента' });
    }

    const entityId = String(req.query.entityId || '').trim();
    if (!entityId) {
      return res.status(400).json({ error: 'entityId обязателен' });
    }

    const hours = parseHoursWindow(req.query.hours, 24);
    const end = new Date();
    const start = new Date(end.getTime() - hours * 60 * 60 * 1000);
    const startIso = start.toISOString();

    const history = await haRequestForUser(req.user.id, {
      path: `/api/history/period/${encodeURIComponent(startIso)}`,
      query: {
        filter_entity_id: entityId,
        end_time: end.toISOString(),
        minimal_response: 'true',
      },
    });

    const rows = Array.isArray(history) ? history[0] || [] : [];
    const items = rows.map((entry) => ({
      entityId: entry?.entity_id || entityId,
      state: entry?.state ?? '',
      lastChanged: entry?.last_changed || '',
      lastUpdated: entry?.last_updated || '',
    }));

    res.json({
      projectId: projectId || null,
      entityId,
      hours,
      items,
    });
  } catch (error) {
    const upstreamStatus = Number(error.statusCode || 0);
    const status = upstreamStatus === 401 ? 502 : (upstreamStatus || 500);
    res.status(status).json({
      error: error.message || 'Ошибка получения истории систем',
      source: upstreamStatus === 401 ? 'home_assistant_auth' : 'server',
      details: error.payload || null,
    });
  }
});

app.post(
  '/api/systems/service',
  authRequired,
  roleRequired('admin', 'director', 'manager', 'foreman'),
  async (req, res) => {
    try {
      const domain = String(req.body.domain || '').trim().toLowerCase();
      const service = String(req.body.service || '').trim().toLowerCase();
      const data = req.body.data && typeof req.body.data === 'object' ? req.body.data : {};
      const projectId = String(req.body.projectId || '').trim();

      if (projectId) {
        await requireProjectAccess(req.user, projectId);
      }

      if (!domain || !service) {
        return res.status(400).json({ error: 'domain и service обязательны' });
      }

      const result = await haRequestForUser(req.user.id, {
        method: 'POST',
        path: `/api/services/${encodeURIComponent(domain)}/${encodeURIComponent(service)}`,
        body: data,
      });

      res.json({
        ok: true,
        result,
      });
    } catch (error) {
      const upstreamStatus = Number(error.statusCode || 0);
      const status = upstreamStatus === 401 ? 502 : (upstreamStatus || 500);
      res.status(status).json({
        error: error.message || 'Ошибка вызова сервиса Home Assistant',
        source: upstreamStatus === 401 ? 'home_assistant_auth' : 'server',
        details: error.payload || null,
      });
    }
  }
);

app.post('/api/auth/login', async (req, res) => {
  try {
    const email = String(req.body.email || '').toLowerCase().trim();
    const password = String(req.body.password || '');
    const otpCode = normalizeOtpCode(req.body.twoFactorCode || '');
    const pendingToken = String(req.body.twoFactorPendingToken || '').trim();
    if (!email || !password) return res.status(400).json({ error: 'Email и пароль обязательны' });

    const { rows } = await pool.query('SELECT * FROM users WHERE email = $1 LIMIT 1', [email]);
    if (!rows.length) return res.status(401).json({ error: 'Неверный email или пароль' });

    const userRow = rows[0];
    if (userRow.is_archived === true) {
      return res.status(403).json({ error: 'Пользователь в архиве' });
    }
    if (userRow.is_active === false) {
      return res.status(403).json({ error: 'Пользователь отключен' });
    }
    const valid = await bcrypt.compare(password, userRow.password_hash);
    if (!valid) return res.status(401).json({ error: 'Неверный email или пароль' });

    if (userRow.two_factor_enabled === true) {
      const userIdFromPending = pendingToken
        ? verifyTwoFactorPendingToken(pendingToken)
        : null;

      if (!otpCode) {
        return res.status(200).json({
          requiresTwoFactor: true,
          twoFactorPendingToken: signTwoFactorPendingToken(userRow.id),
          message: 'Требуется код из Google Authenticator',
        });
      }

      if (!userIdFromPending || userIdFromPending !== String(userRow.id)) {
        return res.status(401).json({ error: 'Сессия подтверждения 2FA истекла' });
      }

      const secret = String(userRow.two_factor_secret || '').trim();
      if (!verifyTotpCode(secret, otpCode)) {
        return res.status(401).json({ error: 'Неверный код 2FA' });
      }
    }

    const user = toUser(userRow);
    const token = signToken(user);
    res.json({ token, user });
  } catch (error) {
    res.status(500).json({ error: 'Ошибка входа' });
  }
});

app.get('/api/auth/me', authRequired, (req, res) => {
  res.json({ user: req.user });
});

app.get('/api/auth/2fa/status', authRequired, async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT two_factor_enabled FROM users WHERE id = $1 LIMIT 1',
      [req.user.id]
    );
    const enabled = rows.length ? rows[0].two_factor_enabled === true : false;
    res.json({ enabled });
  } catch {
    res.status(500).json({ error: 'Не удалось получить статус 2FA' });
  }
});

app.post('/api/auth/2fa/setup', authRequired, async (req, res) => {
  try {
    const email = String(req.user.email || '').trim();
    const secret = authenticator.generateSecret();
    const issuer = 'Lumen Group';
    const otpauthUrl = authenticator.keyuri(email, issuer, secret);
    await pool.query(
      'UPDATE users SET two_factor_secret = $2, two_factor_enabled = FALSE WHERE id = $1',
      [req.user.id, secret]
    );
    res.json({
      secret,
      otpauthUrl,
      account: email,
      issuer,
    });
  } catch {
    res.status(500).json({ error: 'Не удалось подготовить 2FA' });
  }
});

app.post('/api/auth/2fa/enable', authRequired, async (req, res) => {
  try {
    const code = normalizeOtpCode(req.body.code || '');
    if (!code) return res.status(400).json({ error: 'Код обязателен' });

    const { rows } = await pool.query(
      'SELECT two_factor_secret FROM users WHERE id = $1 LIMIT 1',
      [req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Пользователь не найден' });
    const secret = String(rows[0].two_factor_secret || '').trim();
    if (!secret) return res.status(400).json({ error: 'Сначала выполните настройку 2FA' });

    if (!verifyTotpCode(secret, code)) {
      return res.status(400).json({ error: 'Неверный код подтверждения' });
    }

    await pool.query(
      'UPDATE users SET two_factor_enabled = TRUE WHERE id = $1',
      [req.user.id]
    );
    res.json({ ok: true, enabled: true });
  } catch {
    res.status(500).json({ error: 'Не удалось включить 2FA' });
  }
});

app.post('/api/auth/2fa/disable', authRequired, async (req, res) => {
  try {
    const code = normalizeOtpCode(req.body.code || '');
    if (!code) return res.status(400).json({ error: 'Код обязателен' });

    const { rows } = await pool.query(
      'SELECT two_factor_secret, two_factor_enabled FROM users WHERE id = $1 LIMIT 1',
      [req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Пользователь не найден' });
    const secret = String(rows[0].two_factor_secret || '').trim();
    if (!rows[0].two_factor_enabled || !secret) {
      return res.status(400).json({ error: '2FA уже выключена' });
    }

    if (!verifyTotpCode(secret, code)) {
      return res.status(400).json({ error: 'Неверный код подтверждения' });
    }

    await pool.query(
      'UPDATE users SET two_factor_enabled = FALSE, two_factor_secret = NULL WHERE id = $1',
      [req.user.id]
    );
    res.json({ ok: true, enabled: false });
  } catch {
    res.status(500).json({ error: 'Не удалось отключить 2FA' });
  }
});

app.post('/api/push/register', authRequired, async (req, res) => {
  try {
    const token = String(req.body.token || '').trim();
    const platform = String(req.body.platform || 'unknown').trim();
    const tokenType = String(req.body.tokenType || '').trim().toLowerCase();
    const appVersion = String(req.body.appVersion || '').trim();
    const locale = String(req.body.locale || '').trim();
    if (!token) return res.status(400).json({ error: 'token обязателен' });
    const transport = tokenType === 'apns' ? 'apns' : 'fcm';
    const platformStored = `${transport}_${platform || 'unknown'}`;

    await pool.query(
      `INSERT INTO user_push_tokens (id, user_id, token, platform, app_version, locale, last_seen_at)
       VALUES ($1,$2,$3,$4,$5,$6,NOW())
       ON CONFLICT (token) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         platform = EXCLUDED.platform,
         app_version = EXCLUDED.app_version,
         locale = EXCLUDED.locale,
         last_seen_at = NOW()`,
      [randomUUID(), req.user.id, token, platformStored, appVersion || null, locale || null]
    );

    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: 'Не удалось зарегистрировать push токен' });
  }
});

app.delete('/api/push/unregister', authRequired, async (req, res) => {
  try {
    const token = String(req.body?.token || req.query.token || '').trim();
    if (!token) return res.status(400).json({ error: 'token обязателен' });
    await pool.query('DELETE FROM user_push_tokens WHERE user_id = $1 AND token = $2', [req.user.id, token]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: 'Не удалось удалить push токен' });
  }
});

app.get('/api/push/status', authRequired, roleRequired('admin', 'director'), async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT platform, COUNT(*)::int AS count
     FROM user_push_tokens
     GROUP BY platform
     ORDER BY platform`
  );
  res.json({
    fcmConfigured: hasFcmConfig,
    apnsConfigured: hasApnsConfig,
    tokens: rows.map((row) => ({
      platform: row.platform || 'unknown',
      count: Number(row.count || 0),
    })),
  });
});

app.post('/api/push/test', authRequired, async (req, res) => {
  try {
    const title = String(req.body?.title || 'Lumen Group').trim();
    const body = String(req.body?.body || 'Push уведомления подключены').trim();
    await sendPushToUsers({
      userIds: [req.user.id],
      title,
      body,
      data: { type: 'push_test' },
    });
    res.json({ ok: true, fcmConfigured: hasFcmConfig, apnsConfigured: hasApnsConfig });
  } catch (error) {
    res.status(500).json({
      error: error?.message || 'Не удалось отправить тестовое push уведомление',
    });
  }
});

app.get('/api/activity', authRequired, roleRequired('admin', 'director', 'manager'), async (req, res) => {
  try {
    const rawLimit = Number(req.query.limit || 8);
    const limit = Number.isFinite(rawLimit)
      ? Math.min(Math.max(Math.floor(rawLimit), 1), 30)
      : 8;
    const { rows } = await pool.query(
      `
      SELECT * FROM (
        SELECT
          'project_created' AS type,
          id,
          id AS project_id,
          client_user_id,
          'Добавлен новый объект' AS title,
          construction_address AS body,
          created_at AS created_at
        FROM projects

        UNION ALL

        SELECT
          'document_uploaded' AS type,
          id,
          project_id,
          client_user_id,
          'Добавлен новый документ' AS title,
          name AS body,
          uploaded_at AS created_at
        FROM documents

        UNION ALL

        SELECT
          'maintenance_request' AS type,
          id,
          project_id,
          client_user_id,
          CASE
            WHEN status IN ('completed', 'done') THEN 'Заявка выполнена'
            ELSE 'Новая заявка'
          END AS title,
          COALESCE(NULLIF(description, ''), NULLIF(system_type, ''), 'Заявка на обслуживание') AS body,
          updated_at AS created_at
        FROM maintenance_requests

        UNION ALL

        SELECT
          'maintenance_task' AS type,
          t.id,
          t.project_id,
          p.client_user_id,
          CASE
            WHEN t.status IN ('completed', 'done') THEN 'Обслуживание выполнено'
            ELSE 'Запланировано обслуживание'
          END AS title,
          t.title AS body,
          COALESCE(t.completed_at, t.created_at) AS created_at
        FROM maintenance_tasks t
        LEFT JOIN projects p ON p.id = t.project_id

        UNION ALL

        SELECT
          'support_message' AS type,
          m.id,
          '' AS project_id,
          m.client_user_id,
          'Сообщение в поддержке' AS title,
          m.message_text AS body,
          m.created_at AS created_at
        FROM support_messages m

        UNION ALL

        SELECT
          'journal_entry' AS type,
          j.id,
          j.project_id,
          p.client_user_id,
          'Запись в журнале' AS title,
          j.description AS body,
          j.created_at AS created_at
        FROM journal_entries j
        LEFT JOIN projects p ON p.id = j.project_id
      ) activity
      ORDER BY created_at DESC
      LIMIT $1
      `,
      [limit]
    );

    res.json(
      rows.map((row) => ({
        id: `${row.type}-${row.id}`,
        type: row.type,
        title: row.title || 'Активность',
        body: row.body || '',
        createdAt: row.created_at,
        projectId: row.project_id || '',
        clientUserId: row.client_user_id || '',
      }))
    );
  } catch (error) {
    console.error('Activity feed failed:', error);
    res.status(500).json({ error: 'Не удалось загрузить активность' });
  }
});

app.get('/api/users', authRequired, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, email, fio, role, is_active, is_archived, avatar_url FROM users ORDER BY created_at DESC'
  );
  res.json(rows.map(toUser));
});

app.post('/api/users/me/avatar', authRequired, uploadAvatar.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Файл не загружен' });
    const storagePath = `/uploads/avatars/${req.file.filename}`;
    const { rows } = await pool.query(
      'UPDATE users SET avatar_url = $2 WHERE id = $1 RETURNING id, email, fio, role, avatar_url, is_active, is_archived',
      [req.user.id, storagePath]
    );
    if (!rows.length) return res.status(404).json({ error: 'Пользователь не найден' });
    res.json({ avatarUrl: storagePath, user: toUser(rows[0]) });
  } catch (error) {
    res.status(500).json({ error: 'Ошибка загрузки аватара' });
  }
});

app.post(
  '/api/projects/:id/thumbnail',
  authRequired,
  roleRequired('admin', 'director', 'manager', 'foreman'),
  uploadProjectThumbnail.single('file'),
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ error: 'Файл не загружен' });
      const { rows } = await pool.query(
        'SELECT * FROM projects WHERE id = $1 LIMIT 1',
        [req.params.id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Объект не найден' });
      const project = toProject(rows[0]);
      if (!canAccessProject(req.user, project)) {
        return res.status(403).json({ error: 'Forbidden' });
      }

      const storagePath = `/uploads/project-thumbnails/${req.file.filename}`;
      const { rows: updatedRows } = await pool.query(
        'UPDATE projects SET thumbnail_url = $2, updated_at = $3 WHERE id = $1 RETURNING *',
        [req.params.id, storagePath, new Date().toISOString()]
      );
      res.json({ thumbnailUrl: storagePath, project: toProject(updatedRows[0]) });
    } catch {
      res.status(500).json({ error: 'Ошибка загрузки превью' });
    }
  }
);

app.post('/api/users/me/password', authRequired, async (req, res) => {
  try {
    const currentPassword = String(req.body.currentPassword || '');
    const newPassword = String(req.body.newPassword || '');
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Текущий и новый пароль обязательны' });
    }

    const { rows } = await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
    if (!rows.length) return res.status(404).json({ error: 'Пользователь не найден' });

    const valid = await bcrypt.compare(currentPassword, rows[0].password_hash);
    if (!valid) return res.status(400).json({ error: 'Текущий пароль неверен' });

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = $2 WHERE id = $1', [req.user.id, passwordHash]);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: 'Ошибка смены пароля' });
  }
});

app.post('/api/users', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const email = String(req.body.email || '').toLowerCase().trim();
    const password = String(req.body.password || '');
    const fio = String(req.body.fio || '').trim();
    const role = String(req.body.role || 'manager');
    const sendWelcomeEmail = req.body.sendWelcomeEmail !== false;

    if (!email || !password || !fio) {
      return res.status(400).json({ error: 'fio, email, password обязательны' });
    }

    const exists = await pool.query('SELECT id FROM users WHERE email = $1 LIMIT 1', [email]);
    if (exists.rows.length) {
      return res.status(409).json({ error: 'Пользователь с таким email уже существует' });
    }

    const id = randomUUID();
    const passwordHash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      `INSERT INTO users (id, email, password_hash, fio, role, is_active, is_archived)
       VALUES ($1, $2, $3, $4, $5, TRUE, FALSE)
       RETURNING id, email, fio, role, is_active, is_archived`,
      [id, email, passwordHash, fio, role]
    );

    if (sendWelcomeEmail) {
      try {
        await sendUserWelcomeEmail({ fio, email, password, role });
      } catch (mailError) {
        console.warn('Failed to send welcome email:', mailError?.message || mailError);
      }
    }

    res.status(201).json(toUser(rows[0]));
  } catch {
    res.status(500).json({ error: 'Ошибка создания пользователя' });
  }
});

app.patch('/api/users/:id', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const id = req.params.id;
    const fio = String(req.body.fio || '').trim();
    const email = String(req.body.email || '').toLowerCase().trim();
    const role = String(req.body.role || '').trim();
    const password = String(req.body.password || '');

    if (!fio && !email && !role && !password) {
      return res.status(400).json({ error: 'Нет изменений для сохранения' });
    }

    const existing = await pool.query(
      'SELECT id, email, fio, role, password_hash, is_active, is_archived, avatar_url FROM users WHERE id = $1 LIMIT 1',
      [id]
    );
    if (!existing.rows.length) {
      return res.status(404).json({ error: 'Пользователь не найден' });
    }
    const current = existing.rows[0];

    if (email && email !== current.email) {
      const exists = await pool.query('SELECT id FROM users WHERE email = $1 LIMIT 1', [email]);
      if (exists.rows.length) {
        return res.status(409).json({ error: 'Пользователь с таким email уже существует' });
      }
    }

    const nextFio = fio || current.fio;
    const nextEmail = email || current.email;
    const nextRole = role || current.role;
    const nextPasswordHash = password ? await bcrypt.hash(password, 10) : current.password_hash;

    const { rows } = await pool.query(
      `UPDATE users
       SET fio = $2, email = $3, role = $4, password_hash = $5
       WHERE id = $1
       RETURNING id, email, fio, role, is_active, is_archived, avatar_url`,
      [id, nextFio, nextEmail, nextRole, nextPasswordHash]
    );

    res.json(toUser(rows[0]));
  } catch {
    res.status(500).json({ error: 'Ошибка обновления пользователя' });
  }
});

app.delete('/api/users/:id', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  const id = req.params.id;
  if (id === req.user.id) {
    return res.status(400).json({ error: 'Нельзя удалить текущего пользователя' });
  }
  await pool.query('DELETE FROM users WHERE id = $1', [id]);
  res.json({ ok: true });
});

app.patch('/api/users/:id/state', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  const id = req.params.id;
  if (id === req.user.id) {
    return res.status(400).json({ error: 'Нельзя изменить состояние текущего пользователя' });
  }

  const isActiveRaw = req.body?.isActive;
  const isArchivedRaw = req.body?.isArchived;
  if (typeof isActiveRaw !== 'boolean' && typeof isArchivedRaw !== 'boolean') {
    return res.status(400).json({ error: 'Передайте isActive и/или isArchived' });
  }

  const existing = await pool.query(
    'SELECT id, email, fio, role, is_active, is_archived FROM users WHERE id = $1 LIMIT 1',
    [id]
  );
  if (!existing.rows.length) {
    return res.status(404).json({ error: 'Пользователь не найден' });
  }
  const current = existing.rows[0];

  const isArchived = typeof isArchivedRaw === 'boolean' ? isArchivedRaw : current.is_archived;
  const isActive = isArchived ? false : (typeof isActiveRaw === 'boolean' ? isActiveRaw : current.is_active);

  const { rows } = await pool.query(
    `UPDATE users
     SET is_active = $2, is_archived = $3
     WHERE id = $1
     RETURNING id, email, fio, role, is_active, is_archived`,
    [id, isActive, isArchived]
  );
  res.json(toUser(rows[0]));
});

app.get('/api/projects', authRequired, async (req, res) => {
  const isClient = req.user.role === 'client';
  const query = isClient
    ? 'SELECT * FROM projects WHERE client_user_id = $1 ORDER BY created_at DESC'
    : 'SELECT * FROM projects ORDER BY created_at DESC';
  const args = isClient ? [req.user.id] : [];
  const { rows } = await pool.query(query, args);
  res.json(rows.map(toProject));
});

app.get('/api/projects/:id', authRequired, async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM projects WHERE id = $1 LIMIT 1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Объект не найден' });
  const project = toProject(rows[0]);
  if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });
  res.json(project);
});

app.post('/api/projects', authRequired, roleRequired('admin', 'director', 'manager', 'foreman'), async (req, res) => {
  try {
    const payload = req.body;
    const id = randomUUID();
    const now = new Date().toISOString();

    const { rows } = await pool.query(
      `INSERT INTO projects (
        id, client_fio, client_contacts, client_phone, client_email, client_user_id, construction_address,
        thumbnail_url, materials, project_type, area_sqm, estimated_cost, contract_amount, paid_amount, next_payment_date,
        last_payment_date, status, start_date, planned_end_date, actual_end_date, camera_url,
        stages, created_at, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,
        $8,$9,$10,$11,$12,$13,
        $14,$15,$16,$17,$18,$19,
        $20,$21,$22,$23,$24
      ) RETURNING *`,
      [
        id,
        String(payload.clientFio || ''),
        String(payload.clientContacts || payload.clientPhone || ''),
        String(payload.clientPhone || ''),
        String(payload.clientEmail || ''),
        payload.clientUserId || null,
        String(payload.constructionAddress || ''),
        payload.thumbnailUrl || null,
        String(payload.materials || ''),
        String(payload.projectType == null ? 'typical' : payload.projectType),
        safeNum(payload.areaSqm),
        safeNum(payload.estimatedCost),
        payload.contractAmount == null ? null : safeNum(payload.contractAmount),
        payload.paidAmount == null ? null : safeNum(payload.paidAmount),
        payload.nextPaymentDate || null,
        payload.lastPaymentDate || null,
        String(payload.status || 'in_progress'),
        payload.startDate || null,
        payload.plannedEndDate || null,
        payload.actualEndDate || null,
        payload.cameraUrl || null,
        JSON.stringify(Array.isArray(payload.stages) ? payload.stages : []),
        now,
        now,
      ]
    );

    res.status(201).json(toProject(rows[0]));
  } catch {
    res.status(500).json({ error: 'Ошибка создания объекта' });
  }
});

app.patch('/api/projects/:id', authRequired, async (req, res) => {
  const existing = await pool.query('SELECT * FROM projects WHERE id = $1 LIMIT 1', [req.params.id]);
  if (!existing.rows.length) return res.status(404).json({ error: 'Объект не найден' });

  const current = toProject(existing.rows[0]);
  if (!canAccessProject(req.user, current)) return res.status(403).json({ error: 'Forbidden' });
  if (req.user.role === 'client') return res.status(403).json({ error: 'Недостаточно прав для редактирования' });

  const patch = req.body || {};
  const currentStages = Array.isArray(current.stages) ? current.stages : [];
  const merged = {
    ...current,
    ...patch,
    clientUserId: patch.clientUserId ?? current.clientUserId,
    updatedAt: new Date().toISOString(),
  };
  const mergedStages = Array.isArray(merged.stages) ? merged.stages : [];

  const { rows } = await pool.query(
    `UPDATE projects SET
      client_fio=$2,
      client_contacts=$3,
      client_phone=$4,
      client_email=$5,
      client_user_id=$6,
      construction_address=$7,
      thumbnail_url=$8,
      materials=$9,
      project_type=$10,
      area_sqm=$11,
      estimated_cost=$12,
      contract_amount=$13,
      paid_amount=$14,
      next_payment_date=$15,
      last_payment_date=$16,
      status=$17,
      start_date=$18,
      planned_end_date=$19,
      actual_end_date=$20,
      camera_url=$21,
      stages=$22::jsonb,
      updated_at=$23
     WHERE id=$1
     RETURNING *`,
    [
      req.params.id,
      merged.clientFio,
      merged.clientContacts || merged.clientPhone || null,
      merged.clientPhone || null,
      merged.clientEmail || null,
      merged.clientUserId || null,
      merged.constructionAddress,
      merged.thumbnailUrl || null,
      merged.materials || null,
      merged.projectType,
      safeNum(merged.areaSqm),
      safeNum(merged.estimatedCost),
      merged.contractAmount == null ? null : safeNum(merged.contractAmount),
      merged.paidAmount == null ? null : safeNum(merged.paidAmount),
      merged.nextPaymentDate || null,
      merged.lastPaymentDate || null,
      merged.status,
      merged.startDate || null,
      merged.plannedEndDate || null,
      merged.actualEndDate || null,
      merged.cameraUrl || null,
      JSON.stringify(mergedStages),
      merged.updatedAt,
    ]
  );

  const updatedProject = toProject(rows[0]);

  // Create client notifications on stage updates (comment, status, photos, dates).
  const targetClientUserId = await resolveProjectClientUserId(updatedProject);
  if (targetClientUserId) {
    const maxStages = Math.max(currentStages.length, mergedStages.length);
    for (let i = 0; i < maxStages; i += 1) {
      const prevStage = currentStages[i] || {};
      const nextStage = mergedStages[i] || {};
      if (!Object.keys(nextStage).length) continue;

      const prevNorm = normalizeStageForCompare(prevStage);
      const nextNorm = normalizeStageForCompare(nextStage);

      const prevResponsible = prevNorm.stageComment;
      const nextResponsible = nextNorm.stageComment;
      const prevDescription = prevNorm.comments;
      const nextDescription = nextNorm.comments;
      const prevStatus = prevNorm.status;
      const nextStatus = nextNorm.status;
      const prevStart = prevNorm.plannedStart;
      const nextStart = nextNorm.plannedStart;
      const prevEnd = prevNorm.plannedEnd;
      const nextEnd = nextNorm.plannedEnd;
      const prevPhotos = prevNorm.photoUrls.length;
      const nextPhotos = nextNorm.photoUrls.length;

      const changes = [];
      if (prevResponsible !== nextResponsible && nextResponsible) {
        changes.push(`Ответственный: ${nextResponsible}`);
      }
      if (prevDescription !== nextDescription && nextDescription) {
        changes.push(`Комментарий: ${nextDescription}`);
      }
      if (prevStatus !== nextStatus && nextStatus) {
        changes.push(`Статус: ${stageStatusLabelRu(nextStatus)}`);
      }
      if (prevStart !== nextStart || prevEnd !== nextEnd) {
        changes.push(
          `Сроки: ${nextStart || '—'} — ${nextEnd || '—'}`
        );
      }
      if (nextPhotos > prevPhotos) {
        changes.push(`Добавлено фото: +${nextPhotos - prevPhotos}`);
      } else if (nextPhotos < prevPhotos) {
        changes.push(`Удалено фото: ${prevPhotos - nextPhotos}`);
      }

      const stageChanged =
        JSON.stringify(prevNorm) !== JSON.stringify(nextNorm);
      if (!changes.length && !stageChanged) continue;
      if (!changes.length && stageChanged) {
        changes.push('Данные этапа обновлены');
      }
      const notificationText = changes.join(' · ').slice(0, 500);
      const stageName = String(nextStage.name || `Этап ${i + 1}`);
      const stageId = String(nextStage.id || `stage-${i}`);

      await pool.query(
        `INSERT INTO stage_comment_notifications (
          id, client_user_id, project_id, stage_id, stage_name, comment_text, is_read
        ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [
          randomUUID(),
          targetClientUserId,
          updatedProject.id,
          stageId,
          stageName,
          notificationText,
          false,
        ]
      );
      await sendPushToUsers({
        userIds: [targetClientUserId],
        title: `Изменён этап: ${stageName}`,
        body: notificationText,
        data: {
          type: 'stage_comment',
          projectId: updatedProject.id,
          stageId,
        },
      });
    }
  }

  res.json(updatedProject);
});

app.delete('/api/projects/:id', authRequired, roleRequired('admin', 'director', 'manager'), async (req, res) => {
  await pool.query('DELETE FROM projects WHERE id = $1', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/finances/expenses', authRequired, async (req, res) => {
  try {
    const projectId = String(req.query.projectId || '').trim();
    if (!projectId) return res.status(400).json({ error: 'projectId обязателен' });

    const { rows: projectRows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 LIMIT 1',
      [projectId]
    );
    if (!projectRows.length) return res.status(404).json({ error: 'Объект не найден' });

    const project = toProject(projectRows[0]);
    if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });

    const { rows } = await pool.query(
      `SELECT * FROM finance_expenses
       WHERE project_id = $1
       ORDER BY expense_date DESC, created_at DESC`,
      [projectId]
    );

    res.json(rows.map(toFinanceExpense));
  } catch {
    res.status(500).json({ error: 'Не удалось загрузить расходы' });
  }
});

app.post('/api/finances/expenses', authRequired, async (req, res) => {
  try {
    const projectId = String(req.body.projectId || '').trim();
    const category = String(req.body.category || '').trim();
    const amount = Number(req.body.amount);
    const expenseDate = normalizeExpenseDate(req.body.date);
    const note = String(req.body.note || '').trim();

    if (!projectId) return res.status(400).json({ error: 'projectId обязателен' });
    if (!FINANCE_CATEGORIES.has(category)) {
      return res.status(400).json({ error: 'Некорректная категория' });
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Некорректная сумма' });
    }
    if (!expenseDate) {
      return res.status(400).json({ error: 'Некорректная дата' });
    }

    const { rows: projectRows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 LIMIT 1',
      [projectId]
    );
    if (!projectRows.length) return res.status(404).json({ error: 'Объект не найден' });

    const project = toProject(projectRows[0]);
    if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });

    const id = randomUUID();
    const { rows } = await pool.query(
      `INSERT INTO finance_expenses (
        id, project_id, created_by, category, amount, expense_date, note
      ) VALUES ($1,$2,$3,$4,$5,$6,$7)
      RETURNING *`,
      [id, projectId, req.user.id, category, amount, expenseDate, note || null]
    );

    res.status(201).json(toFinanceExpense(rows[0]));
  } catch {
    res.status(500).json({ error: 'Не удалось сохранить расход' });
  }
});

app.delete('/api/finances/expenses/:id', authRequired, async (req, res) => {
  try {
    const expenseId = String(req.params.id || '').trim();
    if (!expenseId) return res.status(400).json({ error: 'id обязателен' });

    const { rows } = await pool.query(
      `SELECT e.*, p.client_user_id
       FROM finance_expenses e
       INNER JOIN projects p ON p.id = e.project_id
       WHERE e.id = $1
       LIMIT 1`,
      [expenseId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Расход не найден' });

    const project = {
      id: rows[0].project_id,
      clientUserId: rows[0].client_user_id || '',
    };
    if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });
    if (req.user.role === 'client' && rows[0].created_by !== req.user.id) {
      return res.status(403).json({ error: 'Недостаточно прав' });
    }
    await pool.query('DELETE FROM finance_expenses WHERE id = $1', [expenseId]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: 'Не удалось удалить расход' });
  }
});

app.get('/api/maintenance/tasks', authRequired, async (req, res) => {
  try {
    const projectId = String(req.query.projectId || '').trim() || null;
    const clientUserId = String(req.query.clientUserId || '').trim() || null;
    const isClient = req.user.role === 'client';

    const params = [];
    const where = [];

    if (projectId) {
      params.push(projectId);
      where.push(`t.project_id = $${params.length}`);
    }
    if (clientUserId) {
      params.push(clientUserId);
      where.push(`p.client_user_id = $${params.length}`);
    }
    if (isClient) {
      params.push(req.user.id);
      where.push(`p.client_user_id = $${params.length}`);
    }

    let sql = `
      SELECT t.*, p.construction_address AS project_address, p.client_user_id
      FROM maintenance_tasks t
      INNER JOIN projects p ON p.id = t.project_id
    `;
    if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
    sql += ' ORDER BY t.scheduled_date ASC, t.created_at DESC';

    const { rows } = await pool.query(sql, params);
    res.json(rows.map(toMaintenanceTask));
  } catch {
    res.status(500).json({ error: 'Не удалось загрузить обслуживание' });
  }
});

app.post('/api/maintenance/tasks', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const projectId = String(req.body.projectId || '').trim();
    const title = String(req.body.title || '').trim();
    const notes = String(req.body.notes || '').trim();
    const scheduledDate = normalizeScheduledDate(req.body.scheduledDate);
    const systemType = String(req.body.systemType || '').trim();

    if (!projectId) return res.status(400).json({ error: 'projectId обязателен' });
    if (!title) return res.status(400).json({ error: 'Название обязательно' });
    if (!scheduledDate) return res.status(400).json({ error: 'Некорректная дата' });

    const { rows: projectRows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 LIMIT 1',
      [projectId]
    );
    if (!projectRows.length) return res.status(404).json({ error: 'Объект не найден' });

    const id = randomUUID();
    const { rows } = await pool.query(
      `INSERT INTO maintenance_tasks (
        id, project_id, title, notes, scheduled_date, status, created_by, system_type
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING *`,
      [id, projectId, title, notes || null, scheduledDate, 'scheduled', req.user.id, systemType || null]
    );

    const taskRow = rows[0];
    const project = toProject(projectRows[0]);
    if (project.clientUserId) {
      await sendPushToUsers({
        userIds: [project.clientUserId],
        title: 'Плановое обслуживание',
        body: `${title} — ${scheduledDate}`,
        data: {
          type: 'maintenance',
          taskId: id,
          projectId,
        },
      });
    }
    res.status(201).json(
      toMaintenanceTask({
        ...taskRow,
        project_address: project.constructionAddress,
        client_user_id: project.clientUserId,
      })
    );
  } catch {
    res.status(500).json({ error: 'Не удалось создать обслуживание' });
  }
});

app.patch('/api/maintenance/tasks/:id', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const id = String(req.params.id || '').trim();
    const title = req.body.title != null ? String(req.body.title || '').trim() : null;
    const notes = req.body.notes != null ? String(req.body.notes || '').trim() : null;
    const scheduledDate = req.body.scheduledDate != null ? normalizeScheduledDate(req.body.scheduledDate) : null;
    const status = req.body.status != null ? String(req.body.status || '').trim() : null;
    const systemType = req.body.systemType != null ? String(req.body.systemType || '').trim() : null;
    const specialistName =
      req.body.specialistName != null ? String(req.body.specialistName || '').trim() : null;
    const reportNotes = req.body.reportNotes != null ? String(req.body.reportNotes || '').trim() : null;
    const reportPhotoUrl =
      req.body.reportPhotoUrl != null ? String(req.body.reportPhotoUrl || '').trim() : null;

    const { rows: existingRows } = await pool.query(
      'SELECT t.*, p.construction_address AS project_address, p.client_user_id FROM maintenance_tasks t INNER JOIN projects p ON p.id = t.project_id WHERE t.id = $1 LIMIT 1',
      [id]
    );
    if (!existingRows.length) return res.status(404).json({ error: 'Задача не найдена' });

    const current = existingRows[0];
    const nextStatus = status || current.status;
    const completedAt = nextStatus == 'completed' ? new Date().toISOString() : null;
    const completedBy = nextStatus == 'completed' ? req.user.id : null;

    const { rows } = await pool.query(
      `UPDATE maintenance_tasks SET
        title = COALESCE($2, title),
        notes = COALESCE($3, notes),
        scheduled_date = COALESCE($4, scheduled_date),
        status = COALESCE($5, status),
        completed_at = COALESCE($6, completed_at),
        completed_by = COALESCE($7, completed_by),
        system_type = COALESCE($8, system_type),
        specialist_name = COALESCE($9, specialist_name),
        report_notes = COALESCE($10, report_notes),
        report_photo_url = COALESCE($11, report_photo_url)
       WHERE id = $1
       RETURNING *`,
      [
        id,
        title,
        notes,
        scheduledDate,
        status,
        completedAt,
        completedBy,
        systemType,
        specialistName,
        reportNotes,
        reportPhotoUrl,
      ]
    );

    if (nextStatus === 'completed' && current.status !== 'completed') {
      const entryId = randomUUID();
      await pool.query(
        `INSERT INTO journal_entries (
          id, project_id, entry_type, description, specialist, entry_date, photo_url, created_by
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [
          entryId,
          current.project_id,
          'maintenance',
          reportNotes || current.notes || current.title,
          specialistName || current.specialist_name || null,
          new Date().toISOString().slice(0, 10),
          reportPhotoUrl || null,
          req.user.id,
        ]
      );
    }

    res.json(
      toMaintenanceTask({
        ...rows[0],
        project_address: current.project_address,
        client_user_id: current.client_user_id,
      })
    );
  } catch {
    res.status(500).json({ error: 'Не удалось обновить обслуживание' });
  }
});

app.delete('/api/maintenance/tasks/:id', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const id = String(req.params.id || '').trim();
    if (!id) return res.status(400).json({ error: 'id обязателен' });

    const { rows } = await pool.query(
      'SELECT t.*, p.client_user_id FROM maintenance_tasks t INNER JOIN projects p ON p.id = t.project_id WHERE t.id = $1 LIMIT 1',
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Задача не найдена' });

    await pool.query('DELETE FROM maintenance_tasks WHERE id = $1', [id]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: 'Не удалось удалить обслуживание' });
  }
});

app.post('/api/journal/photos', authRequired, uploadJournalPhoto.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Файл не загружен' });
  const storagePath = `/uploads/journal-photos/${req.file.filename}`;
  res.json({ storagePath });
});

app.get('/api/journal/entries', authRequired, async (req, res) => {
  try {
    const projectId = String(req.query.projectId || '').trim() || null;
    const clientUserId = String(req.query.clientUserId || '').trim() || null;
    const isClient = req.user.role === 'client';

    const params = [];
    const where = [];

    if (projectId) {
      params.push(projectId);
      where.push(`j.project_id = $${params.length}`);
    }
    if (clientUserId) {
      params.push(clientUserId);
      where.push(`p.client_user_id = $${params.length}`);
    }
    if (isClient) {
      params.push(req.user.id);
      where.push(`p.client_user_id = $${params.length}`);
    }

    let sql = `
      SELECT j.*, p.construction_address AS project_address, p.client_user_id
      FROM journal_entries j
      INNER JOIN projects p ON p.id = j.project_id
    `;
    if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
    sql += ' ORDER BY j.entry_date DESC, j.created_at DESC';

    const { rows } = await pool.query(sql, params);
    res.json(rows.map(toJournalEntry));
  } catch {
    res.status(500).json({ error: 'Не удалось загрузить журнал' });
  }
});

app.post('/api/journal/entries', authRequired, async (req, res) => {
  try {
    const projectId = String(req.body.projectId || '').trim();
    const entryType = String(req.body.entryType || '').trim();
    const description = String(req.body.description || '').trim();
    const specialist = String(req.body.specialist || '').trim();
    const entryDate = normalizeExpenseDate(req.body.entryDate);
    const photoUrl = String(req.body.photoUrl || '').trim();

    if (!projectId) return res.status(400).json({ error: 'projectId обязателен' });
    if (!description) return res.status(400).json({ error: 'Описание обязательно' });
    if (!entryDate) return res.status(400).json({ error: 'Некорректная дата' });
    if (!JOURNAL_ENTRY_TYPES.has(entryType)) {
      return res.status(400).json({ error: 'Некорректный тип записи' });
    }

    const { rows: projectRows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 LIMIT 1',
      [projectId]
    );
    if (!projectRows.length) return res.status(404).json({ error: 'Объект не найден' });
    const project = toProject(projectRows[0]);
    if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });

    const id = randomUUID();
    const { rows } = await pool.query(
      `INSERT INTO journal_entries (
        id, project_id, entry_type, description, specialist, entry_date, photo_url, created_by
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING *`,
      [id, projectId, entryType, description, specialist || null, entryDate, photoUrl || null, req.user.id]
    );

    res.status(201).json(
      toJournalEntry({
        ...rows[0],
        project_address: project.constructionAddress,
        client_user_id: project.clientUserId,
      })
    );
  } catch {
    res.status(500).json({ error: 'Не удалось создать запись' });
  }
});

app.get('/api/maintenance/requests', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId || '').trim() || null;
    const clientUserId = String(req.query.clientUserId || '').trim() || null;

    const params = [];
    const where = [];
    if (projectId) {
      params.push(projectId);
      where.push(`mr.project_id = $${params.length}`);
    }
    if (clientUserId) {
      params.push(clientUserId);
      where.push(`mr.client_user_id = $${params.length}`);
    }

    let sql = `
      SELECT mr.*, p.construction_address AS project_address
      FROM maintenance_requests mr
      LEFT JOIN projects p ON p.id = mr.project_id
    `;
    if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
    sql += ' ORDER BY mr.created_at DESC';

    const { rows } = await pool.query(sql, params);
    res.json(rows.map(toMaintenanceRequest));
  } catch {
    res.status(500).json({ error: 'Не удалось загрузить заявки' });
  }
});

app.post('/api/maintenance/requests', authRequired, async (req, res) => {
  try {
    const projectId = String(req.body.projectId || '').trim();
    const taskId = String(req.body.taskId || '').trim();
    const systemType = String(req.body.systemType || '').trim();
    const description = String(req.body.description || '').trim();
    const preferredDate = normalizeScheduledDate(req.body.preferredDate);

    if (!projectId) return res.status(400).json({ error: 'projectId обязателен' });

    const { rows: projectRows } = await pool.query(
      'SELECT * FROM projects WHERE id = $1 LIMIT 1',
      [projectId]
    );
    if (!projectRows.length) return res.status(404).json({ error: 'Объект не найден' });
    const project = toProject(projectRows[0]);
    if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });

    const id = randomUUID();
    const { rows } = await pool.query(
      `INSERT INTO maintenance_requests (
        id, project_id, task_id, client_user_id, system_type, description, preferred_date, created_by
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING *`,
      [
        id,
        projectId,
        taskId || null,
        project.clientUserId || null,
        systemType || null,
        description || null,
        preferredDate,
        req.user.id,
      ]
    );

    const admins = await pool.query(
      "SELECT id FROM users WHERE role IN ('admin','director','manager') AND is_active = TRUE AND is_archived = FALSE"
    );
    await sendPushToUsers({
      userIds: admins.rows.map((row) => row.id),
      title: 'Новая заявка на обслуживание',
      body: `${project.constructionAddress}: ${description || systemType || 'Без описания'}`,
      data: {
        type: 'maintenance_request',
        requestId: id,
        projectId,
        clientUserId: project.clientUserId || '',
      },
    });

    res.status(201).json(
      toMaintenanceRequest({
        ...rows[0],
        project_address: project.constructionAddress,
        client_user_id: project.clientUserId,
      })
    );
  } catch {
    res.status(500).json({ error: 'Не удалось создать заявку' });
  }
});

app.patch('/api/maintenance/requests/:id', authRequired, roleRequired('admin', 'director'), async (req, res) => {
  try {
    const id = String(req.params.id || '').trim();
    const status = req.body.status != null ? String(req.body.status || '').trim() : null;
    const specialistName =
      req.body.specialistName != null ? String(req.body.specialistName || '').trim() : null;
    const preferredDate =
      req.body.preferredDate != null ? normalizeScheduledDate(req.body.preferredDate) : null;

    const { rows: existing } = await pool.query(
      'SELECT * FROM maintenance_requests WHERE id = $1 LIMIT 1',
      [id]
    );
    if (!existing.length) return res.status(404).json({ error: 'Заявка не найдена' });

    const { rows } = await pool.query(
      `UPDATE maintenance_requests SET
        status = COALESCE($2, status),
        specialist_name = COALESCE($3, specialist_name),
        preferred_date = COALESCE($4, preferred_date),
        updated_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [id, status, specialistName, preferredDate]
    );

    res.json(toMaintenanceRequest(rows[0]));
  } catch {
    res.status(500).json({ error: 'Не удалось обновить заявку' });
  }
});

app.get('/api/documents', authRequired, async (req, res) => {
  const projectId = req.query.projectId ? String(req.query.projectId) : null;
  const clientUserId = req.query.clientUserId ? String(req.query.clientUserId) : null;
  const isClient = req.user.role === 'client';

  let sql = `
    SELECT d.* FROM documents d
    LEFT JOIN projects p ON p.id = d.project_id
  `;
  const where = [];
  const params = [];

  if (projectId) {
    params.push(projectId);
    where.push(`d.project_id = $${params.length}`);
  }
  if (clientUserId) {
    params.push(clientUserId);
    where.push(`(d.client_user_id = $${params.length} OR p.client_user_id = $${params.length})`);
  }
  if (isClient) {
    params.push(req.user.id);
    where.push(`(d.client_user_id = $${params.length} OR p.client_user_id = $${params.length})`);
  }

  if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
  sql += ' ORDER BY d.uploaded_at DESC';

  const { rows } = await pool.query(sql, params);
  res.json(
    rows.map((r) => ({
      id: r.id,
      projectId: r.project_id,
      clientUserId: r.client_user_id,
      projectAddress: r.project_address,
      name: normalizeFilename(r.name),
      type: r.type,
      mimeType: r.mime_type || 'application/octet-stream',
      size: Number(r.size_bytes || 0),
      version: Number(r.version || 1),
      storagePath: r.storage_path,
      uploadedAt: r.uploaded_at,
      uploadedBy: r.uploaded_by,
    }))
  );
});

app.post('/api/documents', authRequired, uploadDocument.single('file'), async (req, res) => {
  if (req.user.role === 'client') {
    return res.status(403).json({ error: 'Клиент не может загружать документы' });
  }
  if (!req.file) return res.status(400).json({ error: 'Файл обязателен' });

  const id = randomUUID();
  const projectId = req.body.projectId ? String(req.body.projectId) : null;
  const clientUserId = req.body.clientUserId ? String(req.body.clientUserId) : null;
  const docType = String(req.body.docType || 'Файл');

  let projectAddress = '';
  if (projectId) {
    const { rows } = await pool.query('SELECT * FROM projects WHERE id = $1 LIMIT 1', [projectId]);
    if (!rows.length) return res.status(404).json({ error: 'Объект не найден' });
    const project = toProject(rows[0]);
    if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });
    projectAddress = project.constructionAddress;
  }

  const originalName = normalizeFilename(req.file.originalname);

  let finalClientUserId = clientUserId;
  if (projectId && !finalClientUserId) {
    const projectData = await pool.query('SELECT client_user_id FROM projects WHERE id = $1 LIMIT 1', [projectId]);
    finalClientUserId = projectData.rows[0]?.client_user_id || null;
  }

  if (finalClientUserId) {
    const existsClient = await pool.query('SELECT id FROM users WHERE id = $1 LIMIT 1', [finalClientUserId]);
    if (!existsClient.rows.length) return res.status(400).json({ error: 'Клиент не найден' });
  }

  const storagePath = `/uploads/documents/${req.file.filename}`;
  const versionQuery = await pool.query(
    `SELECT COALESCE(MAX(version), 0) AS max_version
     FROM documents
     WHERE project_id IS NOT DISTINCT FROM $1
       AND client_user_id IS NOT DISTINCT FROM $2
       AND type = $3
       AND name = $4`,
    [projectId, finalClientUserId, docType, originalName]
  );
  const version = Number(versionQuery.rows[0]?.max_version || 0) + 1;

  const { rows } = await pool.query(
    `INSERT INTO documents (
      id, project_id, client_user_id, project_address, name, mime_type, size_bytes, version, type, storage_path, uploaded_by
    )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING *`,
    [
      id,
      projectId,
      finalClientUserId,
      projectAddress,
      originalName,
      req.file.mimetype || 'application/octet-stream',
      req.file.size || 0,
      version,
      docType,
      storagePath,
      req.user.id,
    ]
  );

  const doc = rows[0];
  res.status(201).json({
    id: doc.id,
    projectId: doc.project_id,
    clientUserId: doc.client_user_id,
    projectAddress: doc.project_address,
    name: normalizeFilename(doc.name),
    type: doc.type,
    mimeType: doc.mime_type || 'application/octet-stream',
    size: Number(doc.size_bytes || 0),
    version: Number(doc.version || 1),
    storagePath: doc.storage_path,
    uploadedAt: doc.uploaded_at,
    uploadedBy: doc.uploaded_by,
  });
});

app.get('/api/documents/:id/preview-html', async (req, res) => {
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const { rows } = await pool.query(
    `SELECT d.*, p.client_user_id AS project_client_user_id
     FROM documents d
     LEFT JOIN projects p ON p.id = d.project_id
     WHERE d.id = $1 LIMIT 1`,
    [req.params.id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Документ не найден' });

  const rec = rows[0];
  const ownerClientId = rec.client_user_id || rec.project_client_user_id;
  if (user.role === 'client' && ownerClientId !== user.id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const absolutePath = path.join(ROOT_DIR, rec.storage_path.replace(/^\//, ''));
  if (!fs.existsSync(absolutePath)) return res.status(404).json({ error: 'Файл не найден' });

  const lowerName = String(rec.name || '').toLowerCase();
  const lowerMime = String(rec.mime_type || '').toLowerCase();
  const isDocx =
    lowerName.endsWith('.docx') ||
    lowerMime.includes('officedocument.wordprocessingml.document');
  if (!isDocx) return res.status(415).json({ error: 'Предпросмотр доступен только для DOCX' });

  try {
    const result = await mammoth.convertToHtml({ path: absolutePath });
    const title = escapeHtml(normalizeFilename(rec.name) || 'Документ');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      html, body { margin: 0; padding: 0; background: #f7f7f8; color: #1f2933; }
      body { font-family: Arial, sans-serif; line-height: 1.55; }
      main { max-width: 900px; margin: 0 auto; padding: 28px 22px 48px; background: #fff; min-height: 100vh; box-sizing: border-box; }
      img { max-width: 100%; height: auto; }
      table { border-collapse: collapse; width: 100%; }
      td, th { border: 1px solid #d7dce1; padding: 6px 8px; }
      p { margin: 0 0 12px; }
    </style>
  </head>
  <body><main>${result.value}</main></body>
</html>`);
  } catch (err) {
    console.error('DOCX preview failed', err);
    res.status(500).json({ error: 'Не удалось открыть предпросмотр Word' });
  }
});

app.get('/api/documents/:id/download', async (req, res) => {
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });
  const { rows } = await pool.query(
    `SELECT d.*, p.client_user_id AS project_client_user_id
     FROM documents d
     LEFT JOIN projects p ON p.id = d.project_id
     WHERE d.id = $1 LIMIT 1`,
    [req.params.id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Документ не найден' });
  const rec = rows[0];
  const ownerClientId = rec.client_user_id || rec.project_client_user_id;
  if (user.role === 'client' && ownerClientId !== user.id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const absolutePath = path.join(ROOT_DIR, rec.storage_path.replace(/^\//, ''));
  if (!fs.existsSync(absolutePath)) return res.status(404).json({ error: 'Файл не найден' });
  const inline = String(req.query.inline || '') === '1';
  if (inline) {
    const displayName = normalizeFilename(rec.name) || 'file';
    const asciiName = filenameForContentDisposition(displayName);
    const utf8Name = encodeURIComponent(displayName);
    res.setHeader('Content-Type', rec.mime_type || 'application/octet-stream');
    res.setHeader(
      'Content-Disposition',
      `inline; filename="${asciiName}"; filename*=UTF-8''${utf8Name}`
    );
    return res.sendFile(absolutePath);
  }
  return res.download(absolutePath, normalizeFilename(rec.name));
});

app.delete('/api/documents/:id', authRequired, async (req, res) => {
  const { rows } = await pool.query(
    `SELECT d.*, p.client_user_id AS project_client_user_id
     FROM documents d
     LEFT JOIN projects p ON p.id = d.project_id
     WHERE d.id = $1 LIMIT 1`,
    [req.params.id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Документ не найден' });

  const rec = rows[0];
  if (req.user.role === 'client') return res.status(403).json({ error: 'Недостаточно прав' });

  const absolutePath = path.join(ROOT_DIR, rec.storage_path.replace(/^\//, ''));
  if (fs.existsSync(absolutePath)) {
    await fsp.unlink(absolutePath).catch(() => {});
  }

  await pool.query('DELETE FROM documents WHERE id = $1', [req.params.id]);
  res.json({ ok: true });
});

app.get('/api/support/messages', authRequired, async (req, res) => {
  try {
    const isClient = req.user.role === 'client';
    const clientUserId = req.query.clientUserId ? String(req.query.clientUserId) : null;

    const params = [];
    const where = [];

    if (isClient) {
      params.push(req.user.id);
      where.push(`m.client_user_id = $${params.length}`);
    } else if (clientUserId) {
      params.push(clientUserId);
      where.push(`m.client_user_id = $${params.length}`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const { rows } = await pool.query(
      `
      SELECT
        m.*,
        sender.fio AS sender_fio,
        sender.role AS sender_role,
        client.fio AS client_fio
      FROM support_messages m
      INNER JOIN users sender ON sender.id = m.sender_user_id
      INNER JOIN users client ON client.id = m.client_user_id
      ${whereSql}
      ORDER BY m.created_at ASC
      `,
      params
    );

    res.json(rows.map(toSupportMessage));
  } catch {
    res.status(500).json({ error: 'Ошибка загрузки чата поддержки' });
  }
});

app.post('/api/support/messages', authRequired, async (req, res) => {
  try {
    const messageText = String(req.body.messageText || '').trim();
    if (!messageText) return res.status(400).json({ error: 'Сообщение не может быть пустым' });

    const isClient = req.user.role === 'client';
    let clientUserId = isClient ? req.user.id : String(req.body.clientUserId || '').trim();

    if (!clientUserId) {
      return res.status(400).json({ error: 'Выберите клиента для переписки' });
    }

    const clientUser = await pool.query('SELECT id, role FROM users WHERE id = $1 LIMIT 1', [clientUserId]);
    if (!clientUser.rows.length || clientUser.rows[0].role !== 'client') {
      return res.status(400).json({ error: 'Клиент не найден' });
    }

    const id = randomUUID();
    const isReadByAdmin = req.user.role !== 'client';
    const { rows } = await pool.query(
      `
      INSERT INTO support_messages (id, client_user_id, sender_user_id, message_text, is_read_by_admin)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
      `,
      [id, clientUserId, req.user.id, messageText, isReadByAdmin]
    );

    const { rows: messageRows } = await pool.query(
      `
      SELECT
        m.*,
        sender.fio AS sender_fio,
        sender.role AS sender_role,
        client.fio AS client_fio
      FROM support_messages m
      INNER JOIN users sender ON sender.id = m.sender_user_id
      INNER JOIN users client ON client.id = m.client_user_id
      WHERE m.id = $1
      LIMIT 1
      `,
      [rows[0].id]
    );

    const targetUserIds = req.user.role === 'client' ? [] : [clientUserId];
    if (req.user.role === 'client') {
      const admins = await pool.query(
        "SELECT id FROM users WHERE role IN ('admin','director','manager') AND is_active = TRUE AND is_archived = FALSE"
      );
      targetUserIds.push(...admins.rows.map((row) => row.id));
    }
    await sendPushToUsers({
      userIds: targetUserIds,
      title: req.user.role === 'client' ? 'Новое сообщение в поддержке' : 'Ответ в поддержке',
      body: messageText,
      data: {
        type: req.user.role === 'client' ? 'support_incoming' : 'support_reply',
        messageId: rows[0].id,
        clientUserId,
      },
    });

    res.status(201).json(toSupportMessage(messageRows[0]));
  } catch {
    res.status(500).json({ error: 'Ошибка отправки сообщения' });
  }
});

app.patch('/api/support/chats/:clientUserId/read', authRequired, async (req, res) => {
  if (req.user.role === 'client') return res.status(403).json({ error: 'Недостаточно прав' });

  const clientUserId = String(req.params.clientUserId || '').trim();
  if (!clientUserId) return res.status(400).json({ error: 'Клиент не указан' });

  await pool.query(
    `
    UPDATE support_messages
    SET is_read_by_admin = TRUE
    WHERE client_user_id = $1
      AND sender_user_id <> $2
      AND is_read_by_admin = FALSE
    `,
    [clientUserId, req.user.id]
  );

  res.json({ ok: true });
});

app.delete('/api/support/chats/:clientUserId', authRequired, async (req, res) => {
  if (req.user.role === 'client') return res.status(403).json({ error: 'Недостаточно прав' });

  const clientUserId = String(req.params.clientUserId || '').trim();
  if (!clientUserId) return res.status(400).json({ error: 'Клиент не указан' });

  await pool.query('DELETE FROM support_messages WHERE client_user_id = $1', [clientUserId]);
  res.json({ ok: true });
});

app.get('/api/notifications', authRequired, async (req, res) => {
  try {
    const isClient = req.user.role === 'client';
    const clientUserId = req.query.clientUserId ? String(req.query.clientUserId) : null;

    const params = [req.user.id];
    const where = [];
    where.push('h.notification_id IS NULL');

    if (isClient) {
      where.push('n.client_user_id = $1');
    } else if (clientUserId) {
      params.push(clientUserId);
      where.push(`n.client_user_id = $${params.length}`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const { rows } = await pool.query(
      `
      SELECT
        n.*,
        p.construction_address AS project_address
      FROM stage_comment_notifications n
      LEFT JOIN projects p ON p.id = n.project_id
      LEFT JOIN stage_comment_notification_hidden h
        ON h.notification_id = n.id
       AND h.user_id = $1
      ${whereSql}
      ORDER BY n.created_at DESC
      `,
      params
    );

    res.json(rows.map(toStageCommentNotification));
  } catch {
    res.status(500).json({ error: 'Ошибка загрузки уведомлений' });
  }
});

app.get('/api/notifications/feed', authRequired, async (req, res) => {
  try {
    const isClient = req.user.role === 'client';
    const clientUserId = req.query.clientUserId ? String(req.query.clientUserId) : null;

    const stageParams = [req.user.id];
    const stageWhere = ['h.notification_id IS NULL'];
    if (isClient) {
      stageWhere.push('n.client_user_id = $1');
    } else if (clientUserId) {
      stageParams.push(clientUserId);
      stageWhere.push(`n.client_user_id = $${stageParams.length}`);
    }

    const stageWhereSql = stageWhere.length ? `WHERE ${stageWhere.join(' AND ')}` : '';
    const stageResult = await pool.query(
      `
      SELECT
        n.*,
        p.construction_address AS project_address
      FROM stage_comment_notifications n
      LEFT JOIN projects p ON p.id = n.project_id
      LEFT JOIN stage_comment_notification_hidden h
        ON h.notification_id = n.id
       AND h.user_id = $1
      ${stageWhereSql}
      ORDER BY n.created_at DESC
      `,
      stageParams
    );

    const stageItems = stageResult.rows.map(toStageCommentNotification);
    let supportItems = [];
    let maintenanceItems = [];
    let maintenanceRequestItems = [];
    if (isClient) {
      const supportResult = await pool.query(
        `
        SELECT
          m.id,
          m.client_user_id,
          m.message_text,
          m.created_at,
          sender.fio AS sender_fio
        FROM support_messages m
        LEFT JOIN users sender ON sender.id = m.sender_user_id
        LEFT JOIN support_message_notification_hidden sh
          ON sh.message_id = m.id
         AND sh.user_id = $1
        WHERE m.client_user_id = $1
          AND m.sender_user_id <> m.client_user_id
          AND sh.message_id IS NULL
        ORDER BY m.created_at DESC
        LIMIT 300
        `,
        [req.user.id]
      );
      supportItems = supportResult.rows.map(toSupportReplyNotification);

      const maintenanceResult = await pool.query(
        `
        SELECT
          t.*,
          p.construction_address AS project_address,
          p.client_user_id
        FROM maintenance_tasks t
        INNER JOIN projects p ON p.id = t.project_id
        LEFT JOIN maintenance_notification_hidden mh
          ON mh.task_id = t.id
         AND mh.user_id = $1
        WHERE p.client_user_id = $1
          AND t.status = 'scheduled'
          AND mh.task_id IS NULL
          AND (
            t.scheduled_date <= (CURRENT_DATE + INTERVAL '30 days')
            OR t.scheduled_date < CURRENT_DATE
          )
        ORDER BY t.scheduled_date ASC
        LIMIT 300
        `,
        [req.user.id]
      );
      maintenanceItems = maintenanceResult.rows.map(toMaintenanceNotification);
    } else {
      const supportParams = [req.user.id];
      const supportWhere = [
        'm.sender_user_id = m.client_user_id',
        'sh.message_id IS NULL',
      ];
      if (clientUserId) {
        supportParams.push(clientUserId);
        supportWhere.push(`m.client_user_id = $${supportParams.length}`);
      }
      const supportWhereSql = supportWhere.length
        ? `WHERE ${supportWhere.join(' AND ')}`
        : '';
      const supportResult = await pool.query(
        `
        SELECT
          m.id,
          m.client_user_id,
          m.message_text,
          m.created_at,
          m.is_read_by_admin,
          client.fio AS client_fio
        FROM support_messages m
        LEFT JOIN users client ON client.id = m.client_user_id
        LEFT JOIN support_message_notification_hidden sh
          ON sh.message_id = m.id
         AND sh.user_id = $1
        ${supportWhereSql}
        ORDER BY m.created_at DESC
        LIMIT 300
        `,
        supportParams
      );
      supportItems = supportResult.rows.map(toSupportIncomingAdminNotification);

      const requestParams = [req.user.id];
      const requestWhere = [
        'mr.status IN (\'new\', \'pending\')',
        'mh.request_id IS NULL',
      ];
      if (clientUserId) {
        requestParams.push(clientUserId);
        requestWhere.push(`mr.client_user_id = $${requestParams.length}`);
      }
      const requestWhereSql = requestWhere.length
        ? `WHERE ${requestWhere.join(' AND ')}`
        : '';
      const requestResult = await pool.query(
        `
        SELECT
          mr.*,
          p.construction_address AS project_address
        FROM maintenance_requests mr
        LEFT JOIN projects p ON p.id = mr.project_id
        LEFT JOIN maintenance_request_notification_hidden mh
          ON mh.request_id = mr.id
         AND mh.user_id = $1
        ${requestWhereSql}
        ORDER BY mr.created_at DESC
        LIMIT 300
        `,
        requestParams
      );
      maintenanceRequestItems = requestResult.rows.map(toMaintenanceRequestNotification);
    }
    const merged = [...stageItems, ...supportItems, ...maintenanceItems, ...maintenanceRequestItems].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

    res.json(merged);
  } catch {
    res.status(500).json({ error: 'Ошибка загрузки уведомлений' });
  }
});

app.patch('/api/notifications/:id/read', authRequired, async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ error: 'ID уведомления обязателен' });

  const { rows } = await pool.query('SELECT * FROM stage_comment_notifications WHERE id = $1 LIMIT 1', [id]);
  if (!rows.length) return res.status(404).json({ error: 'Уведомление не найдено' });

  const rec = rows[0];
  if (req.user.role === 'client' && rec.client_user_id !== req.user.id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  await pool.query('UPDATE stage_comment_notifications SET is_read = TRUE WHERE id = $1', [id]);
  res.json({ ok: true });
});

app.patch('/api/notifications/support/:id/read', authRequired, async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ error: 'ID уведомления обязателен' });

  const { rows } = await pool.query('SELECT * FROM support_messages WHERE id = $1 LIMIT 1', [id]);
  if (!rows.length) return res.status(404).json({ error: 'Уведомление не найдено' });

  const rec = rows[0];
  if (req.user.role === 'client') {
    if (rec.client_user_id !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    return res.json({ ok: true });
  }

  await pool.query('UPDATE support_messages SET is_read_by_admin = TRUE WHERE id = $1', [id]);
  return res.json({ ok: true });
});

app.patch('/api/notifications/maintenance/:id/read', authRequired, async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ error: 'ID уведомления обязателен' });

  const { rows } = await pool.query('SELECT * FROM maintenance_tasks WHERE id = $1 LIMIT 1', [id]);
  if (!rows.length) return res.status(404).json({ error: 'Уведомление не найдено' });

  const rec = rows[0];
  if (req.user.role === 'client') {
    const { rows: projectRows } = await pool.query(
      'SELECT client_user_id FROM projects WHERE id = $1 LIMIT 1',
      [rec.project_id]
    );
    if (!projectRows.length || projectRows[0].client_user_id !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden' });
    }
  }

  await pool.query(
    'INSERT INTO maintenance_notification_hidden (task_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [id, req.user.id]
  );
  res.json({ ok: true });
});

app.patch('/api/notifications/maintenance-requests/:id/read', authRequired, async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ error: 'ID уведомления обязателен' });

  const { rows } = await pool.query('SELECT * FROM maintenance_requests WHERE id = $1 LIMIT 1', [id]);
  if (!rows.length) return res.status(404).json({ error: 'Уведомление не найдено' });

  if (req.user.role !== 'admin' && req.user.role !== 'director') {
    return res.status(403).json({ error: 'Forbidden' });
  }

  await pool.query(
    'INSERT INTO maintenance_request_notification_hidden (request_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [id, req.user.id]
  );
  res.json({ ok: true });
});

app.patch('/api/notifications/read-all', authRequired, async (req, res) => {
  if (req.user.role === 'client') {
    await pool.query('UPDATE stage_comment_notifications SET is_read = TRUE WHERE client_user_id = $1', [req.user.id]);
    return res.json({ ok: true });
  }

  const clientUserId = String(req.body.clientUserId || '').trim();
  if (!clientUserId) {
    await pool.query('UPDATE stage_comment_notifications SET is_read = TRUE');
    await pool.query('UPDATE support_messages SET is_read_by_admin = TRUE WHERE sender_user_id = client_user_id');
    await pool.query(
      `
      INSERT INTO maintenance_request_notification_hidden (request_id, user_id)
      SELECT id, $1
      FROM maintenance_requests
      ON CONFLICT (request_id, user_id) DO NOTHING
      `,
      [req.user.id]
    );
    return res.json({ ok: true });
  }
  await pool.query('UPDATE stage_comment_notifications SET is_read = TRUE WHERE client_user_id = $1', [clientUserId]);
  await pool.query(
    'UPDATE support_messages SET is_read_by_admin = TRUE WHERE client_user_id = $1 AND sender_user_id = client_user_id',
    [clientUserId]
  );
  await pool.query(
    `
    INSERT INTO maintenance_request_notification_hidden (request_id, user_id)
    SELECT id, $1
    FROM maintenance_requests
    WHERE client_user_id = $2
    ON CONFLICT (request_id, user_id) DO NOTHING
    `,
    [req.user.id, clientUserId]
  );
  return res.json({ ok: true });
});

app.delete('/api/notifications/clear-all', authRequired, async (req, res) => {
  const viewerUserId = req.user.id;
  const isClient = req.user.role === 'client';
  const clientUserId = String(req.body?.clientUserId || '').trim() || null;

  if (isClient) {
    await pool.query(
      `
      INSERT INTO stage_comment_notification_hidden (notification_id, user_id)
      SELECT id, $1
      FROM stage_comment_notifications
      WHERE client_user_id = $1
      ON CONFLICT (notification_id, user_id) DO NOTHING
      `,
      [viewerUserId]
    );
    await pool.query(
      `
      INSERT INTO maintenance_notification_hidden (task_id, user_id)
      SELECT t.id, $1
      FROM maintenance_tasks t
      INNER JOIN projects p ON p.id = t.project_id
      WHERE p.client_user_id = $1
      ON CONFLICT (task_id, user_id) DO NOTHING
      `,
      [viewerUserId]
    );
    await pool.query(
      `
      INSERT INTO support_message_notification_hidden (message_id, user_id)
      SELECT id, $1
      FROM support_messages
      WHERE client_user_id = $1
        AND sender_user_id <> client_user_id
      ON CONFLICT (message_id, user_id) DO NOTHING
      `,
      [viewerUserId]
    );
    return res.json({ ok: true });
  }

  if (clientUserId) {
    await pool.query(
      `
      INSERT INTO stage_comment_notification_hidden (notification_id, user_id)
      SELECT id, $1
      FROM stage_comment_notifications
      WHERE client_user_id = $2
      ON CONFLICT (notification_id, user_id) DO NOTHING
      `,
      [viewerUserId, clientUserId]
    );
    await pool.query(
      `
      INSERT INTO support_message_notification_hidden (message_id, user_id)
      SELECT id, $1
      FROM support_messages
      WHERE client_user_id = $2
        AND sender_user_id = client_user_id
      ON CONFLICT (message_id, user_id) DO NOTHING
      `,
      [viewerUserId, clientUserId]
    );
    await pool.query(
      `
      INSERT INTO maintenance_notification_hidden (task_id, user_id)
      SELECT t.id, $1
      FROM maintenance_tasks t
      INNER JOIN projects p ON p.id = t.project_id
      WHERE p.client_user_id = $2
      ON CONFLICT (task_id, user_id) DO NOTHING
      `,
      [viewerUserId, clientUserId]
    );
    await pool.query(
      `
      INSERT INTO maintenance_request_notification_hidden (request_id, user_id)
      SELECT id, $1
      FROM maintenance_requests
      WHERE client_user_id = $2
      ON CONFLICT (request_id, user_id) DO NOTHING
      `,
      [viewerUserId, clientUserId]
    );
    return res.json({ ok: true });
  }

  await pool.query(
    `
    INSERT INTO stage_comment_notification_hidden (notification_id, user_id)
    SELECT id, $1
    FROM stage_comment_notifications
    ON CONFLICT (notification_id, user_id) DO NOTHING
    `,
    [viewerUserId]
  );
  await pool.query(
    `
    INSERT INTO support_message_notification_hidden (message_id, user_id)
    SELECT id, $1
    FROM support_messages
    WHERE sender_user_id = client_user_id
    ON CONFLICT (message_id, user_id) DO NOTHING
    `,
    [viewerUserId]
  );
  await pool.query(
    `
    INSERT INTO maintenance_notification_hidden (task_id, user_id)
    SELECT id, $1
    FROM maintenance_tasks
    ON CONFLICT (task_id, user_id) DO NOTHING
    `,
    [viewerUserId]
  );
  await pool.query(
    `
    INSERT INTO maintenance_request_notification_hidden (request_id, user_id)
    SELECT id, $1
    FROM maintenance_requests
    ON CONFLICT (request_id, user_id) DO NOTHING
    `,
    [viewerUserId]
  );
  return res.json({ ok: true });
});

app.post(
  '/api/projects/:id/stages/:stageIndex/photos',
  authRequired,
  uploadStagePhoto.fields([
    { name: 'files', maxCount: 20 },
    { name: 'file', maxCount: 20 },
  ]),
  async (req, res) => {
  const uploadedByFilesField = Array.isArray(req.files?.files) ? req.files.files : [];
  const uploadedByFileField = Array.isArray(req.files?.file) ? req.files.file : [];
  const files = [...uploadedByFilesField, ...uploadedByFileField];
  if (!files.length) return res.status(400).json({ error: 'Файл обязателен' });
  if (req.user.role === 'client') return res.status(403).json({ error: 'Недостаточно прав' });

  const stageIndex = Number(req.params.stageIndex);
  const { rows } = await pool.query('SELECT * FROM projects WHERE id = $1 LIMIT 1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Объект не найден' });

  const project = toProject(rows[0]);
  if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });
  const nextStages = Array.isArray(project.stages) ? [...project.stages] : [];
  if (!nextStages[stageIndex]) {
    return res.status(400).json({ error: 'Этап не найден' });
  }

  const photoUrls = Array.isArray(nextStages[stageIndex].photoUrls) ? [...nextStages[stageIndex].photoUrls] : [];
  for (const file of files) {
    photoUrls.push(`/uploads/stage-photos/${file.filename}`);
  }
  nextStages[stageIndex] = { ...nextStages[stageIndex], photoUrls };

  const { rows: updatedRows } = await pool.query(
    'UPDATE projects SET stages = $2::jsonb, updated_at = $3 WHERE id = $1 RETURNING *',
    [req.params.id, JSON.stringify(nextStages), new Date().toISOString()]
  );

  const updatedProject = toProject(updatedRows[0]);
  const targetClientUserId = await resolveProjectClientUserId(updatedProject);
  if (targetClientUserId) {
    const stage = nextStages[stageIndex] || {};
    const stageName = String(stage.name || `Этап ${stageIndex + 1}`);
    const stageId = String(stage.id || `stage-${stageIndex}`);
    const text = `Добавлено фото: +${files.length}`;
    await pool.query(
      `INSERT INTO stage_comment_notifications (
        id, client_user_id, project_id, stage_id, stage_name, comment_text, is_read
      ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [
        randomUUID(),
        targetClientUserId,
        updatedProject.id,
        stageId,
        stageName,
        text,
        false,
      ]
    );
    await sendPushToUsers({
      userIds: [targetClientUserId],
      title: `Обновлён этап: ${stageName}`,
      body: text,
      data: {
        type: 'stage_comment',
        projectId: updatedProject.id,
        stageId,
      },
    });
  }

  res.json(updatedProject);
});

app.delete('/api/projects/:id/stages/:stageIndex/photos', authRequired, async (req, res) => {
  if (req.user.role === 'client') return res.status(403).json({ error: 'Недостаточно прав' });
  const stageIndex = Number(req.params.stageIndex);
  const photoUrl = String(req.body.photoUrl || '');

  const { rows } = await pool.query('SELECT * FROM projects WHERE id = $1 LIMIT 1', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Объект не найден' });

  const project = toProject(rows[0]);
  if (!canAccessProject(req.user, project)) return res.status(403).json({ error: 'Forbidden' });
  const nextStages = Array.isArray(project.stages) ? [...project.stages] : [];
  if (!nextStages[stageIndex]) {
    return res.status(400).json({ error: 'Этап не найден' });
  }

  const photoUrls = Array.isArray(nextStages[stageIndex].photoUrls)
    ? nextStages[stageIndex].photoUrls.filter((x) => x !== photoUrl)
    : [];
  nextStages[stageIndex] = { ...nextStages[stageIndex], photoUrls };

  const absolutePath = path.join(ROOT_DIR, photoUrl.replace(/^\//, ''));
  if (photoUrl && fs.existsSync(absolutePath)) {
    await fsp.unlink(absolutePath).catch(() => {});
  }

  const { rows: updatedRows } = await pool.query(
    'UPDATE projects SET stages = $2::jsonb, updated_at = $3 WHERE id = $1 RETURNING *',
    [req.params.id, JSON.stringify(nextStages), new Date().toISOString()]
  );

  const updatedProject = toProject(updatedRows[0]);
  const targetClientUserId = await resolveProjectClientUserId(updatedProject);
  if (targetClientUserId) {
    const stage = nextStages[stageIndex] || {};
    const stageName = String(stage.name || `Этап ${stageIndex + 1}`);
    const stageId = String(stage.id || `stage-${stageIndex}`);
    const text = 'Удалено фото';
    await pool.query(
      `INSERT INTO stage_comment_notifications (
        id, client_user_id, project_id, stage_id, stage_name, comment_text, is_read
      ) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [
        randomUUID(),
        targetClientUserId,
        updatedProject.id,
        stageId,
        stageName,
        text,
        false,
      ]
    );
    await sendPushToUsers({
      userIds: [targetClientUserId],
      title: `Обновлён этап: ${stageName}`,
      body: text,
      data: {
        type: 'stage_comment',
        projectId: updatedProject.id,
        stageId,
      },
    });
  }

  res.json(updatedProject);
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Внутренняя ошибка сервера' });
});

bootstrap()
  .then(() => {
    app.listen(Number(PORT), () => {
      console.log(`API started on http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('Failed to start server', err);
    process.exit(1);
  });
