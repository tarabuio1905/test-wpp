from flask import Flask, request, jsonify
import requests
import openai
import os

# Configuração de variáveis de ambiente
app = Flask("app")

META_ACCESS_TOKEN = os.getenv("META_ACCESS_TOKEN")
WHATSAPP_PHONE_NUMBER_ID = os.getenv("WHATSAPP_PHONE_NUMBER_ID")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
VERIFY_TOKEN = os.getenv("VERIFY_TOKEN")

# Configuração da API OpenAI
openai.api_key = OPENAI_API_KEY

# Endpoint de verificação
app.route('/webhook', methods=['GET'])
def verify():
    mode = request.args.get('hub.mode')
    token = request.args.get('hub.verify_token')
    challenge = request.args.get('hub.challenge')

    if mode == "subscribe" and token == VERIFY_TOKEN:
        return challenge, 200
    return "Verificação falhou", 403

# Processamento de mensagens
app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json

    if data.get("object") == "whatsapp_business_account":
        for entry in data["entry"]:
            for change in entry["changes"]:
                value = change["value"]
                messages = value.get("messages", [])
                if messages:
                    message = messages[0]
                    phone_number = message["from"]
                    text = message["text"]["body"]

                    # Enviando mensagem para a OpenAI
                    response = openai.Completion.create(
                        engine="text-davinci-003",
                        prompt=text,
                        max_tokens=150
                    )

                    reply_text = response['choices'][0]['text'].strip()

                    # Enviando resposta via WhatsApp
                    send_whatsapp_message(phone_number, reply_text)

    return "Mensagem processada", 200

# Função para enviar mensagens ao WhatsApp
def send_whatsapp_message(phone_number, message_text):
    url = f"https://graph.facebook.com/v17.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"
    headers = {
        "Authorization": f"Bearer {META_ACCESS_TOKEN}",
        "Content-Type": "application/json"
    }
    payload = {
        "messaging_product": "whatsapp",
        "to": phone_number,
        "type": "text",
        "text": {"body": message_text}
    }

    response = requests.post(url, headers=headers, json=payload)
    return response.json()

if __name__ == '__main__':
    app.run(port=5000, debug=True)
