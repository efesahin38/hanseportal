process.env.TZ = 'Europe/Berlin';
const express = require('express');
const cors = require('cors');
const { supabase, supabaseAdmin } = require('./supabaseClient');
const reporter = require('./reporter');
const admin = require('firebase-admin');
require('dotenv').config();

// Firebase Admin Init
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  serviceAccount = require('./serviceAccountKey.json');
}
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  console.log(`[HTTP] ${req.method} ${req.url} - ${new Date().toISOString()}`);
  next();
});

app.post('/api/debug', (req, res) => {
  console.log('[FLUTTER-DEBUG]', req.body.log);
  res.json({ ok: true });
});

reporter.startCronJobs();

// ============================================================
// YARDIMCI: FCM Push Bildirimi Gönder
// ============================================================
async function sendFcmToUsers(userIds, title, body) {
  try {
    const uniqueIds = [...new Set(userIds.filter(Boolean))];
    if (uniqueIds.length === 0) return;
    const { data: users } = await supabase.from('users').select('fcm_token').in('id', uniqueIds);
    const tokens = (users || []).map(u => u.fcm_token).filter(t => t && t.length > 0);
    if (tokens.length === 0) {
      console.log('[FCM] Bildirim gönderilecek token bulunamadı.');
      return;
    }
    const result = await admin.messaging().sendEachForMulticast({
      notification: { title, body },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'high_importance_channel' } },
      apns: { payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } } },
      tokens,
    });
    console.log(`[FCM] ${result.successCount} başarı, ${result.failureCount} hata`);
  } catch (e) {
    console.error('[FCM] Hata:', e.message);
  }
}

// YARDIMCI: Bir iş için yöneticileri bildir (Betriebsleiter + ilgili Bereichsleiter)
async function notifyOrderManagers(orderId, title, body, excludeUserId = null) {
  try {
    const { data: order } = await supabase
      .from('orders')
      .select('responsible_user_id, department_id, company_id')
      .eq('id', orderId)
      .single();
    if (!order) return;

    // Betriebsleiter (şirketteki tüm)
    const { data: betriebsleiterList } = await supabase
      .from('users')
      .select('id')
      .eq('role', 'betriebsleiter')
      .eq('company_id', order.company_id)
      .eq('status', 'active');

    const recipientIds = new Set();
    (betriebsleiterList || []).forEach(u => recipientIds.add(u.id));

    // Sorumlu Bereichsleiter
    if (order.responsible_user_id) recipientIds.add(order.responsible_user_id);

    // Aynı departmandaki Bereichsleiter
    if (order.department_id) {
      const { data: bereichsleiterList } = await supabase
        .from('users')
        .select('id')
        .eq('role', 'bereichsleiter')
        .eq('department_id', order.department_id)
        .eq('status', 'active');
      (bereichsleiterList || []).forEach(u => recipientIds.add(u.id));
    }

    // Bildirimi gönderen kişiyi çıkar
    if (excludeUserId) recipientIds.delete(excludeUserId);

    // DB'ye bildirim kaydet
    const insertRows = [...recipientIds].map(uid => ({
      recipient_id: uid,
      notification_type: 'task_update',
      title,
      body,
      order_id: orderId,
    }));
    if (insertRows.length > 0) {
      await supabase.from('notifications').insert(insertRows);
    }

    // FCM push
    await sendFcmToUsers([...recipientIds], title, body);
  } catch (e) {
    console.error('[notifyOrderManagers] Hata:', e.message);
  }
}

// ============================================================
// AUTH
// ============================================================

// POST /api/auth/login – Email + PIN veya Email + Password
app.post('/api/auth/login', async (req, res) => {
  try {
    const { id, pin_code } = req.body;
    if (!id || !pin_code) return res.status(400).json({ error: 'ID ve PIN zorunludur.' });

    const { data: user, error } = await supabase
      .from('users')
      .select('id, first_name, last_name, role, company_id, email, department_id, status')
      .eq('id', id)
      .eq('pin_code', pin_code)
      .eq('status', 'active')
      .single();

    if (error || !user) return res.status(401).json({ error: 'Hatalı ID veya PIN.' });
    res.json({ user });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/users/:id/fcm-token
app.post('/api/users/:id/fcm-token', async (req, res) => {
  try {
    const { id } = req.params;
    const { fcm_token } = req.body;
    if (!fcm_token || fcm_token.trim() === '') {
      await supabase.from('users').update({ fcm_token: null }).eq('id', id);
      return res.json({ message: 'Token silindi.' });
    }
    await supabase.from('users').update({ fcm_token: null }).eq('fcm_token', fcm_token);
    await supabase.from('users').update({ fcm_token }).eq('id', id);
    res.json({ message: 'Token kaydedildi.' });
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// ORDERS – BİLDİRİM ENTEGRASYONLU
// ============================================================

// POST /api/orders/notify-new – Yeni iş oluşturulduğunda çağrılır (Flutter'dan)
app.post('/api/orders/notify-new', async (req, res) => {
  try {
    const { order_id, created_by } = req.body;
    if (!order_id) return res.status(400).json({ error: 'order_id zorunludur.' });

    const { data: order } = await supabase
      .from('orders')
      .select('title, order_number, customer:customers(name)')
      .eq('id', order_id)
      .single();

    if (!order) return res.status(404).json({ error: 'İş bulunamadı.' });

    const customerName = order.customer?.name || '';
    const title = '📋 Neuer Auftrag';
    const body = `${order.title}${customerName ? ' – ' + customerName : ''} (${order.order_number || ''})`.trim();

    await notifyOrderManagers(order_id, title, body, created_by);
    res.json({ message: 'Bildirimler gönderildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/orders/:id/notify-status – İş durumu değiştiğinde çağrılır
app.post('/api/orders/:id/notify-status', async (req, res) => {
  try {
    const { id } = req.params;
    const { new_status, changed_by } = req.body;
    if (!new_status) return res.status(400).json({ error: 'new_status zorunludur.' });

    const { data: order } = await supabase
      .from('orders')
      .select('title, order_number, customer:customers(name)')
      .eq('id', id)
      .single();

    if (!order) return res.status(404).json({ error: 'İş bulunamadı.' });

    const statusLabels = {
      draft: 'Entwurf', created: 'Erstellt', pending_approval: 'Wartet auf Genehmigung',
      approved: 'Genehmigt', planning: 'In Planung', in_progress: 'In Bearbeitung',
      completed: 'Abgeschlossen', invoiced: 'Fakturiert', archived: 'Archiviert',
    };
    const statusLabel = statusLabels[new_status] || new_status;
    const title = '🔄 Auftrag aktualisiert';
    const body = `${order.title} → ${statusLabel} (${order.order_number || ''})`;

    await notifyOrderManagers(id, title, body, changed_by);
    res.json({ message: 'Bildirimler gönderildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/extra-works/notify-new – Ek iş eklendiğinde çağrılır
app.post('/api/extra-works/notify-new', async (req, res) => {
  try {
    const { extra_work_id, recorded_by } = req.body;
    if (!extra_work_id) return res.status(400).json({ error: 'extra_work_id zorunludur.' });

    const { data: ew } = await supabase
      .from('extra_works')
      .select('title, order_id, duration_h')
      .eq('id', extra_work_id)
      .single();

    if (!ew) return res.status(404).json({ error: 'Ek iş bulunamadı.' });

    const title = '➕ Zusatzarbeit erfasst';
    const body = `${ew.title}${ew.duration_h ? ' – ' + ew.duration_h + ' Std.' : ''} – Genehmigung erforderlich`;

    await notifyOrderManagers(ew.order_id, title, body, recorded_by);
    res.json({ message: 'Bildirimler gönderildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/work-sessions/notify-start – Çalışma başlatıldığında çağrılır
app.post('/api/work-sessions/notify-start', async (req, res) => {
  try {
    const { session_id } = req.body;
    if (!session_id) return res.status(400).json({ error: 'session_id zorunludur.' });

    const { data: session } = await supabase
      .from('work_sessions')
      .select('user_id, order_id, operation_plan_id, order:orders(title), user:users(first_name, last_name)')
      .eq('id', session_id)
      .single();

    if (!session) return res.status(404).json({ error: 'Seans bulunamadı.' });

    const workerName = `${session.user?.first_name || ''} ${session.user?.last_name || ''}`.trim();
    const title = '🟢 Arbeit gestartet';
    const body = `${workerName} hat mit der Arbeit begonnen – ${session.order?.title || ''}`;

    // Saha sorumlusunu bul (varsa)
    const recipientIds = new Set();
    if (session.operation_plan_id) {
      const { data: plan } = await supabase
        .from('operation_plans')
        .select('site_supervisor_id')
        .eq('id', session.operation_plan_id)
        .single();
      if (plan?.site_supervisor_id && plan.site_supervisor_id !== session.user_id) {
        recipientIds.add(plan.site_supervisor_id);
      }
    }

    // DB bildirimi
    if (recipientIds.size > 0) {
      const insertRows = [...recipientIds].map(uid => ({
        recipient_id: uid,
        notification_type: 'task_update',
        title,
        body,
        order_id: session.order_id,
        operation_plan_id: session.operation_plan_id,
      }));
      await supabase.from('notifications').insert(insertRows);
      await sendFcmToUsers([...recipientIds], title, body);
    }

    // Yöneticilere de bildir
    await notifyOrderManagers(session.order_id, title, body, session.user_id);
    res.json({ message: 'Bildirimler gönderildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// POST /api/work-sessions/notify-end – Çalışma bittiğinde çağrılır
app.post('/api/work-sessions/notify-end', async (req, res) => {
  try {
    const { session_id } = req.body;
    if (!session_id) return res.status(400).json({ error: 'session_id zorunludur.' });

    const { data: session } = await supabase
      .from('work_sessions')
      .select('user_id, order_id, actual_duration_h, order:orders(title), user:users(first_name, last_name)')
      .eq('id', session_id)
      .single();

    if (!session) return res.status(404).json({ error: 'Seans bulunamadı.' });

    const workerName = `${session.user?.first_name || ''} ${session.user?.last_name || ''}`.trim();
    const hours = session.actual_duration_h ? parseFloat(session.actual_duration_h).toFixed(1) : '?';
    const title = '🔴 Arbeit beendet';
    const body = `${workerName} hat die Arbeit beendet – ${hours} Std. – ${session.order?.title || ''}`;

    await notifyOrderManagers(session.order_id, title, body, session.user_id);
    res.json({ message: 'Bildirimler gönderildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// COMPANIES
// ============================================================
app.get('/api/companies', async (req, res) => {
  try {
    const { data, error } = await supabase.from('companies').select('*').order('name');
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// USERS / PERSONEL (YENİ ŞEMA)
// ============================================================

// GET /api/users – Tüm personel listesi
app.get('/api/users', async (req, res) => {
  try {
    const { company_id, role, status } = req.query;
    let query = supabase.from('users').select(
      'id, first_name, last_name, email, phone, role, status, company_id, department_id, employee_number, position_title'
    );
    if (company_id) query = query.eq('company_id', company_id);
    if (role) query = query.eq('role', role);
    if (status) query = query.eq('status', status); else query = query.eq('status', 'active');
    const { data, error } = await query.order('last_name');
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// GET /api/users/:id
app.get('/api/users/:id', async (req, res) => {
  try {
    const { data, error } = await supabase.from('users').select('*').eq('id', req.params.id).single();
    if (error || !data) return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });
    res.json(data);
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// POST /api/users – Yeni personel ekle (Güvenli Supabase Auth Bağlantılı)
app.post('/api/users', async (req, res) => {
  try {
    const { first_name, last_name, email, phone, role, company_id, department_id, position_title, pin_code, employee_number, password } = req.body;
    if (!first_name || !last_name || !email || !company_id) {
      return res.status(400).json({ error: 'Ad, soyad, e-posta ve şirket zorunludur.' });
    }
    const validRoles = ['geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'vorarbeiter', 'mitarbeiter', 'buchhaltung', 'backoffice', 'system_admin'];
    const userRole = validRoles.includes(role) ? role : 'mitarbeiter';
    
    // 1. Supabase Auth'ta kullanıcıyı yarat
    const defaultPassword = password || '111111';
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: defaultPassword,
      email_confirm: true
    });

    if (authError) {
      if (!authError.message.includes('already exists')) {
        return res.status(400).json({ error: 'Güvenlik hesabı oluşturulamadı: ' + authError.message });
      }
    }

    // Zaten varsa (veya az önce oluşturduysak) Auth ID'yi al
    let finalAuthId = authData?.user?.id;
    if (!finalAuthId) {
       const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
       const existingUser = existingUsers?.users?.find(u => u.email === email);
       if (existingUser) finalAuthId = existingUser.id;
    }

    // 2. Public users tablosuna ekle
    const { data, error } = await supabase.from('users').insert({
      auth_id: finalAuthId,
      first_name, last_name, email, phone,
      role: userRole, company_id, department_id, position_title, pin_code, employee_number,
      status: 'active',
    }).select().single();

    if (error) return res.status(500).json({ error: error.message });
    res.status(201).json({ message: 'Çalışan başarıyla oluşturuldu.', user: data });
  } catch (err) { 
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' }); 
  }
});

// PATCH /api/users/:id – Güncelle
app.patch('/api/users/:id', async (req, res) => {
  try {
    const allowed = ['first_name', 'last_name', 'email', 'phone', 'role', 'status', 'department_id', 'position_title', 'pin_code', 'employee_number', 'weekly_hours', 'employment_type', 'notes'];
    const updates = {};
    for (const k of allowed) { if (req.body[k] !== undefined) updates[k] = req.body[k]; }
    const { data, error } = await supabase.from('users').update(updates).eq('id', req.params.id).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Güncellendi.', user: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// PATCH /api/users/:id/deactivate – Pasife al (silme yerine)
app.patch('/api/users/:id/deactivate', async (req, res) => {
  try {
    const { data: user } = await supabase.from('users').select('role').eq('id', req.params.id).single();
    if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı.' });
    if (user.role === 'geschaeftsfuehrer' || user.role === 'system_admin') {
      return res.status(403).json({ error: 'Bu rol pasife alınamaz.' });
    }
    await supabase.from('users').update({ status: 'inactive' }).eq('id', req.params.id);
    res.json({ message: 'Kullanıcı pasife alındı.' });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// ============================================================
// OPERATION PLANS – YENİ ŞEMA
// ============================================================

// GET /api/operation-plans?date=YYYY-MM-DD&order_id=...
app.get('/api/operation-plans', async (req, res) => {
  try {
    const { date, order_id, company_id } = req.query;
    let query = supabase.from('operation_plans').select(`
      *,
      order:orders(id, title, order_number, site_address, customer:customers(id, name)),
      site_supervisor:users!operation_plans_site_supervisor_id_fkey(id, first_name, last_name),
      operation_plan_personnel(user_id, is_supervisor, users(id, first_name, last_name, role))
    `);
    if (order_id) query = query.eq('order_id', order_id);
    if (date) query = query.eq('plan_date', date);
    const { data, error } = await query.order('plan_date').order('start_time');
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// POST /api/operation-plans – Yeni plan oluştur
app.post('/api/operation-plans', async (req, res) => {
  try {
    const { order_id, plan_date, start_time, end_time, site_supervisor_id, planned_by, site_instructions, equipment_notes, material_notes, notes } = req.body;
    if (!order_id || !plan_date || !start_time) {
      return res.status(400).json({ error: 'İş, tarih ve başlangıç saati zorunludur.' });
    }

    const { data: plan, error } = await supabase.from('operation_plans').insert({
      order_id, plan_date, start_time, end_time, site_supervisor_id, planned_by,
      site_instructions, equipment_notes, material_notes, notes, status: 'draft',
    }).select().single();

    if (error) return res.status(500).json({ error: error.message });
    res.status(201).json({ message: 'Plan oluşturuldu.', plan });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// POST /api/operation-plans/:id/assign – Personel ata + FCM bildirim
app.post('/api/operation-plans/:id/assign', async (req, res) => {
  try {
    const { id } = req.params;
    const { user_ids, assigned_by, send_notification = true } = req.body;
    if (!user_ids || !Array.isArray(user_ids) || user_ids.length === 0) {
      return res.status(400).json({ error: 'En az bir personel seçilmelidir.' });
    }

    // Çakışma kontrolü
    const { data: plan } = await supabase.from('operation_plans').select('plan_date').eq('id', id).single();
    if (plan) {
      const { data: conflicts } = await supabase
        .from('operation_plan_personnel')
        .select('user_id, operation_plans!inner(plan_date)')
        .eq('operation_plans.plan_date', plan.plan_date)
        .in('user_id', user_ids)
        .neq('operation_plan_id', id);

      if (conflicts && conflicts.length > 0) {
        const conflictIds = [...new Set(conflicts.map(c => c.user_id))];
        const { data: conflictUsers } = await supabase
          .from('users')
          .select('first_name, last_name')
          .in('id', conflictIds);
        const names = (conflictUsers || []).map(u => `${u.first_name} ${u.last_name}`).join(', ');
        return res.status(409).json({
          error: `${names} aynı tarihte başka bir plana atanmış.`,
          conflict_user_ids: conflictIds
        });
      }
    }

    // Mevcut atamaları temizle
    await supabase.from('operation_plan_personnel').delete().eq('operation_plan_id', id);

    // Yeni atamaları ekle
    const rows = user_ids.map(uid => ({ operation_plan_id: id, user_id: uid, assigned_by }));
    const { error } = await supabase.from('operation_plan_personnel').insert(rows);
    if (error) return res.status(500).json({ error: error.message });

    // Planı "sent" durumuna güncelle (trigger notifications + calendar)
    await supabase.from('operation_plans').update({ status: 'sent', notification_sent: true, notification_sent_at: new Date().toISOString() }).eq('id', id);

    // FCM push bildirim
    if (send_notification) {
      const { data: orderInfo } = await supabase
        .from('operation_plans')
        .select('plan_date, start_time, order:orders(title)')
        .eq('id', id)
        .single();

      const title = '📋 Yeni Görev Atandı!';
      const body = orderInfo
        ? `${orderInfo.order?.title} – ${orderInfo.plan_date} ${orderInfo.start_time || ''}`
        : 'Yeni göreviniz var. Detaylar için uygulamaya bakın.';

      await sendFcmToUsers(user_ids, title, body);
    }

    res.json({ message: 'Personel atandı ve bildirimler gönderildi.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// PATCH /api/operation-plans/:id – Güncelle
app.patch('/api/operation-plans/:id', async (req, res) => {
  try {
    const allowed = ['plan_date', 'start_time', 'end_time', 'site_supervisor_id', 'site_instructions', 'equipment_notes', 'material_notes', 'notes', 'status'];
    const updates = {};
    for (const k of allowed) { if (req.body[k] !== undefined) updates[k] = req.body[k]; }
    const { data, error } = await supabase.from('operation_plans').update(updates).eq('id', req.params.id).select().single();
    if (error) return res.status(500).json({ error: error.message });

    // Güncelleme bildirimi gönder (eğer plan zaten sent ise)
    if (data.notification_sent) {
      const { data: personnel } = await supabase
        .from('operation_plan_personnel')
        .select('user_id')
        .eq('operation_plan_id', req.params.id);
      if (personnel && personnel.length > 0) {
        await sendFcmToUsers(personnel.map(p => p.user_id), '🔄 Plan Güncellendi', 'Görev planınız güncellendi. Detaylara bakın.');
      }
    }

    res.json({ message: 'Plan güncellendi.', plan: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// ============================================================
// WORK SESSIONS – YENİ ŞEMA (mobil saha)
// ============================================================

// POST /api/work-sessions/start
app.post('/api/work-sessions/start', async (req, res) => {
  try {
    const { order_id, user_id, operation_plan_id, minimum_hours, latitude, longitude } = req.body;
    if (!order_id || !user_id) return res.status(400).json({ error: 'İş ve kullanıcı ID zorunludur.' });

    // Zaten aktif seans var mı?
    const { data: existing } = await supabase.from('work_sessions').select('id').eq('user_id', user_id).eq('status', 'started').maybeSingle();
    if (existing) return res.status(409).json({ error: 'Zaten aktif bir çalışma seansınız var.' });

    const { data, error } = await supabase.from('work_sessions').insert({
      order_id, user_id, operation_plan_id,
      actual_start: new Date().toISOString(),
      minimum_hours: minimum_hours || null,
      status: 'started',
      start_latitude: latitude,
      start_longitude: longitude,
    }).select().single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Çalışma başlatıldı!', session: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// POST /api/work-sessions/:id/end
app.post('/api/work-sessions/:id/end', async (req, res) => {
  try {
    const { id } = req.params;
    const { note, latitude, longitude } = req.body;

    const { data: session } = await supabase.from('work_sessions').select('*').eq('id', id).single();
    if (!session) return res.status(404).json({ error: 'Seans bulunamadı.' });
    if (session.status !== 'started') return res.status(400).json({ error: 'Aktif seans bulunamadı.' });

    const { data, error } = await supabase.from('work_sessions').update({
      actual_end: new Date().toISOString(),
      note,
      end_latitude: latitude,
      end_longitude: longitude,
    }).eq('id', id).select().single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Çalışma tamamlandı!', session: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// GET /api/work-sessions/active/:user_id
app.get('/api/work-sessions/active/:user_id', async (req, res) => {
  try {
    const { data, error } = await supabase.from('work_sessions')
      .select('*, order:orders(id, title, order_number, site_address)')
      .eq('user_id', req.params.user_id).eq('status', 'started').maybeSingle();
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// GET /api/work-sessions/my/:user_id – Personelin görevleri
app.get('/api/work-sessions/my/:user_id', async (req, res) => {
  try {
    const { data, error } = await supabase.from('operation_plan_personnel')
      .select(`
        operation_plan_id, is_supervisor,
        operation_plans(id, plan_date, start_time, end_time, status, site_instructions, order:orders(id, title, order_number, site_address, customer:customers(id, name)))
      `)
      .eq('user_id', req.params.user_id)
      .order('created_at', { ascending: false });
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// PATCH /api/work-sessions/:id/adjust – Manuel süre düzeltme (yetkili)
app.patch('/api/work-sessions/:id/adjust', async (req, res) => {
  try {
    const { adjusted_by, actual_start, actual_end, adjustment_reason } = req.body;
    if (!adjusted_by) return res.status(400).json({ error: 'adjusted_by zorunludur.' });

    const { data: adjuster } = await supabase.from('users').select('role').eq('id', adjusted_by).single();
    if (!adjuster || !['geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin'].includes(adjuster.role)) {
      return res.status(403).json({ error: 'Bu işlem için yetkiniz yok.' });
    }

    const updates = { is_manually_adjusted: true, adjusted_by, adjustment_reason };
    if (actual_start) updates.actual_start = actual_start;
    if (actual_end) updates.actual_end = actual_end;

    const { data, error } = await supabase.from('work_sessions').update(updates).eq('id', req.params.id).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Süre güncellendi.', session: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// ============================================================
// DAILY TRACKER – YENİ ŞEMA
// ============================================================
app.get('/api/today/activity', async (req, res) => {
  try {
    const date = req.query.date || new Date().toISOString().split('T')[0];
    const { data, error } = await supabase
      .from('operation_plan_personnel')
      .select(`
        user_id, is_supervisor,
        users(id, first_name, last_name, role),
        operation_plans!inner(
          id, plan_date, start_time, end_time, status, site_instructions,
          order:orders(id, title, site_address, customer:customers(id, name))
        )
      `)
      .eq('operation_plans.plan_date', date)
      .in('operation_plans.status', ['sent', 'confirmed']);

    if (error) return res.status(500).json({ error: error.message });

    // İlgili work_sessions al
    const planIds = (data || []).map(d => d.operation_plans?.id).filter(Boolean);
    const { data: sessions } = await supabase.from('work_sessions')
      .select('user_id, status, actual_start, actual_end')
      .in('operation_plan_id', planIds);

    const sessionMap = {};
    (sessions || []).forEach(s => { sessionMap[s.user_id] = s; });

    const result = (data || []).map(d => ({
      user_id: d.user_id,
      user_name: `${d.users?.first_name || ''} ${d.users?.last_name || ''}`.trim(),
      role: d.users?.role,
      is_supervisor: d.is_supervisor,
      plan: d.operation_plans,
      session: sessionMap[d.user_id] || null,
    }));

    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// ============================================================
// ADMIN - TEST ENDPOINTS
// ============================================================
app.get('/api/admin/trigger-daily', async (req, res) => {
  await reporter.sendDailyReport();
  res.json({ message: 'Günlük Rapor Tetiklendi!' });
});

app.get('/api/admin/trigger-monthly', async (req, res) => {
  await reporter.sendMonthlyReport();
  res.json({ message: 'Aylık Rapor Tetiklendi!' });
});

// ============================================================
// EXTRA WORKS – FCM bildirim ile
// ============================================================
app.post('/api/extra-works/:id/approve', async (req, res) => {
  try {
    const { approved_by } = req.body;
    const { data: approver } = await supabase.from('users').select('role').eq('id', approved_by).single();
    if (!approver || !['geschaeftsfuehrer', 'betriebsleiter', 'bereichsleiter', 'system_admin'].includes(approver.role)) {
      return res.status(403).json({ error: 'Yetkiniz yok.' });
    }
    const { data, error } = await supabase.from('extra_works')
      .update({ status: 'approved', approved_by, approved_at: new Date().toISOString() })
      .eq('id', req.params.id).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.json({ message: 'Ek iş onaylandı.', extra_work: data });
  } catch (err) { res.status(500).json({ error: 'Sunucu hatası' }); }
});

// ============================================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[SERVER] ${PORT} portunda çalışıyor.`);
});
