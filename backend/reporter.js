process.env.TZ = 'Europe/Berlin';
const nodemailer = require('nodemailer');
const cron = require('node-cron');
const supabase = require('./supabaseClient');
const admin = require('firebase-admin');
require('dotenv').config();

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});

function toCSV(data) {
  if (!data || !data.length) return 'KAYIT BULUNAMADI';
  const keys = Object.keys(data[0]);
  const header = keys.join(',');
  const rows = data.map(row => keys.map(k => {
    let val = row[k];
    if (val === null || val === undefined) val = '';
    return `"${val.toString().replace(/"/g, '""')}"`;
  }).join(','));
  return [header, ...rows].join('\r\n');
}

async function sendDailyReport() {
  try {
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;

    const { data: plans, error } = await supabase
      .from('shift_plans')
      .select(`id, company_id, work_date, start_time, end_time, status, companies(name), shift_assignments(worker_name, role_in_shift, shift_status, actual_start, actual_end, total_hours)`)
      .eq('work_date', todayStr);

    if (error) throw error;

    // Flatten
    const rows = [];
    if (plans) {
      plans.forEach(plan => {
        (plan.shift_assignments || []).forEach(a => {
          rows.push({
            tarih: plan.work_date,
            sirket: plan.companies?.name || plan.company_id,
            calisan: a.worker_name,
            rol: a.role_in_shift === 'leader' ? 'LİDER' : 'ÇALIŞAN',
            plan_baslangic: plan.start_time,
            plan_bitis: plan.end_time,
            gercek_baslangic: a.actual_start || '',
            gercek_bitis: a.actual_end || '',
            toplam_saat: a.total_hours || '',
            durum: a.shift_status
          });
        });
      });
    }

    const csvBuffer = Buffer.concat([Buffer.from('\ufeff','utf8'), Buffer.from(toCSV(rows), 'utf8')]);

    await transporter.sendMail({
      from: `"Ekrem PDKS Otomasyon" <${process.env.EMAIL_USER}>`,
      to: 'efeshn.business@gmail.com',
      subject: `Ekrem PDKS Günlük Rapor - ${todayStr}`,
      text: `Merhaba,\n\n${todayStr} tarihine ait tüm vardiya ve mesai kayıtları ektedir.\n\nİyi çalışmalar.`,
      attachments: [{ filename: `Gunluk_Rapor_${todayStr}.csv`, content: csvBuffer }]
    });
    console.log(`Günlük rapor gönderildi! (${todayStr})`);
  } catch (err) {
    console.error('Günlük Rapor Hatası:', err);
  }
}

async function sendMonthlyReport() {
  try {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;

    const { data: summaries, error } = await supabase
      .from('monthly_summaries')
      .select('employee_id, employee_name, report_month, report_year, total_hours, total_sessions')
      .eq('report_year', year)
      .eq('report_month', month);

    if (error) throw error;
    const csvBuffer = Buffer.concat([Buffer.from('\ufeff','utf8'), Buffer.from(toCSV(summaries || []), 'utf8')]);

    await transporter.sendMail({
      from: `"Ekrem PDKS Otomasyon" <${process.env.EMAIL_USER}>`,
      to: 'efeshn.business@gmail.com',
      subject: `Ekrem PDKS Aylık Özet - ${month}/${year}`,
      text: `Merhaba,\n\n${month}/${year} dönemine ait tüm personel mesai özetleri ektedir.`,
      attachments: [{ filename: `Aylik_Rapor_${month}_${year}.csv`, content: csvBuffer }]
    });
    console.log(`Aylık rapor gönderildi! (${month}/${year})`);
  } catch (err) {
    console.error('Aylık Rapor Hatası:', err);
  }
}

// ============================================
// BİLDİRİM (PUSH) HATIRLATICILARI
// ============================================
async function sendPush(token, title, body) {
  try {
    if (!token) return;
    await admin.messaging().send({
      token: token,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'high_importance_channel' }
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1, contentAvailable: true }
        }
      }
    });
    console.log(`[FCM] Bildirim başarıyla gönderildi (${title})`);
  } catch (e) {
    console.error('Firebase push hatası:', e.message);
  }
}

async function checkShiftReminders() {
  try {
    const nowLocal = new Date();
    const todayStr = `${nowLocal.getFullYear()}-${String(nowLocal.getMonth()+1).padStart(2,'0')}-${String(nowLocal.getDate()).padStart(2,'0')}`;
    const currentTotalMins = nowLocal.getHours() * 60 + nowLocal.getMinutes();

    console.log(`[Hatırlatıcı] Kontrol: ${todayStr}, saat: ${nowLocal.getHours()}:${String(nowLocal.getMinutes()).padStart(2,'0')}`);

    // 1. Adım: Bugünün onaylı planlarındaki tüm atamaları al (worker_id dahil)
    const { data: assignments, error } = await supabase
      .from('shift_assignments')
      .select('worker_id, shift_status, shift_plans(work_date, start_time, end_time, status)')
      .eq('shift_plans.work_date', todayStr)
      .eq('shift_plans.status', 'approved');

    if (error) { console.error('[Hatırlatıcı] Atama sorgu hatası:', error.message); return; }
    if (!assignments || assignments.length === 0) { console.log('[Hatırlatıcı] Bugün için onaylı atama bulunamadı.'); return; }

    console.log(`[Hatırlatıcı] ${assignments.length} atama bulundu.`);

    for (const a of assignments) {
      if (!a.shift_plans) continue;

      // 2. Adım: O işçinin FCM tokenını doğrudan users tablosundan çek
      const { data: userRow } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', a.worker_id)
        .single();

      const fcmToken = userRow?.fcm_token;
      if (!fcmToken) {
        console.log(`[Hatırlatıcı] Worker ${a.worker_id} için FCM token yok, atlanıyor.`);
        continue;
      }

      if (a.shift_status === 'assigned') {
        // Başlamamış mesai: 5 dk kala uyar
        const [sh, sm] = a.shift_plans.start_time.split(':').map(Number);
        const startTotalMins = sh * 60 + sm;
        const diffToStart = startTotalMins - currentTotalMins;
        console.log(`[Hatırlatıcı] Worker ${a.worker_id}: başlangıca ${diffToStart} dk kaldı.`);
        if (diffToStart === 5) {
          console.log(`[Hatırlatıcı] Worker ${a.worker_id}'ye BAŞLAMA bildirimi gönderiliyor!`);
          await sendPush(fcmToken, '⏰ Mesai Başlıyor!', 'Birazdan mesain başlayacak, iyi işler.');
        }
      } else if (a.shift_status === 'active') {
        // Aktif mesai: Bitişe 1 dk kala uyar
        const [eh, em] = a.shift_plans.end_time.split(':').map(Number);
        let endTotalMins = eh * 60 + em;
        if (endTotalMins < currentTotalMins) endTotalMins += 24 * 60;
        const diffToEnd = endTotalMins - currentTotalMins;
        console.log(`[Hatırlatıcı] Worker ${a.worker_id}: bitişe ${diffToEnd} dk kaldı.`);
        if (diffToEnd === 1) {
          console.log(`[Hatırlatıcı] Worker ${a.worker_id}'ye BİTİŞ bildirimi gönderiliyor!`);
          await sendPush(fcmToken, '⏳ Mesai Bitiyor!', 'Mesaini bitirebilirsin.');
        }
      }
    }
  } catch (err) {
    console.error('Hatırlatıcı kontrol hatası:', err);
  }
}

function startCronJobs() {
  cron.schedule('50 23 * * *', () => { console.log('Günlük rapor tetiklendi'); sendDailyReport(); });
  cron.schedule('55 23 * * *', () => {
    const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1);
    if (tomorrow.getDate() === 1) { console.log('Aylık rapor tetiklendi'); sendMonthlyReport(); }
  });
  
  // Her 1 dakikada bir kontrol (Hatırlatıcı)
  cron.schedule('* * * * *', () => {
    checkShiftReminders();
  });
  
  console.log('Zamanlanmış Rapor Görevleri ve Hatırlatıcılar Başlatıldı!');
}

module.exports = { sendDailyReport, sendMonthlyReport, startCronJobs };
